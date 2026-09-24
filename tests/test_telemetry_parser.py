#!/usr/bin/env python3
"""
Unit tests for system telemetry parsing (CPU, RAM, Battery) with mock isolation.
Enforces Rule 12 (TDD Mandate), Rule 13 (Edge Cases), Rule 14 (Mocking).
"""

import unittest
from typing import Dict, Optional, Tuple


def parse_cpu_stat(prev_stat: Tuple[int, int], stat_line: str) -> Tuple[float, Tuple[int, int]]:
    """
    Parses a /proc/stat 'cpu ' line and returns (cpu_percentage, (total, idle)).
    Line format: cpu  user nice system idle iowait irq softirq steal guest guest_nice
    """
    if not stat_line or not stat_line.startswith("cpu "):
        raise ValueError("Invalid /proc/stat cpu line format")

    parts = stat_line.split()
    if len(parts) < 5:
        raise ValueError("Malformed cpu stats line, insufficient fields")

    try:
        fields = [int(p) for p in parts[1:]]
    except ValueError as e:
        raise ValueError(f"Non-integer value in stat line: {e}") from e

    user, nice, system, idle = fields[0], fields[1], fields[2], fields[3]
    iowait = fields[4] if len(fields) > 4 else 0
    irq = fields[5] if len(fields) > 5 else 0
    softirq = fields[6] if len(fields) > 6 else 0
    steal = fields[7] if len(fields) > 7 else 0

    idle_time = idle + iowait
    non_idle = user + nice + system + irq + softirq + steal
    total_time = idle_time + non_idle

    prev_total, prev_idle = prev_stat
    total_delta = total_time - prev_total
    idle_delta = idle_time - prev_idle

    if total_delta <= 0:
        return 0.0, (total_time, idle_time)

    cpu_usage = ((total_delta - idle_delta) / total_delta) * 100.0
    return max(0.0, min(100.0, round(cpu_usage, 2))), (total_time, idle_time)


def parse_meminfo(meminfo_content: str) -> Dict[str, float]:
    """
    Parses /proc/meminfo and returns dictionary with total, available, used, and percent.
    """
    if not meminfo_content:
        raise ValueError("Empty meminfo content")

    data: Dict[str, int] = {}
    for line in meminfo_content.strip().splitlines():
        parts = line.split(":")
        if len(parts) == 2:
            key = parts[0].strip()
            val_parts = parts[1].strip().split()
            if val_parts:
                try:
                    data[key] = int(val_parts[0])  # in kB
                except ValueError:
                    continue

    total_kb = data.get("MemTotal", 0)
    avail_kb = data.get("MemAvailable", 0)

    if total_kb <= 0:
        return {"total_mb": 0.0, "used_mb": 0.0, "percent": 0.0}

    used_kb = max(0, total_kb - avail_kb)
    percent = (used_kb / total_kb) * 100.0

    return {
        "total_mb": round(total_kb / 1024.0, 1),
        "used_mb": round(used_kb / 1024.0, 1),
        "percent": max(0.0, min(100.0, round(percent, 1))),
    }


def parse_battery_info(
    capacity_str: Optional[str],
    status_str: Optional[str]
) -> Dict[str, Optional[object]]:
    """
    Safely parses battery /sys/class/power_supply/BAT* capacity and status files.
    Returns fail-safe defaults if files do not exist (desktop PC).
    """
    if capacity_str is None or status_str is None:
        return {
            "has_battery": False,
            "percentage": 0,
            "charging": False,
            "status": "Unknown",
        }

    try:
        capacity = int(capacity_str.strip())
        capacity = max(0, min(100, capacity))
    except (ValueError, AttributeError):
        capacity = 0

    status = status_str.strip() if status_str else "Unknown"
    charging = status in ("Charging", "Full")

    return {
        "has_battery": True,
        "percentage": capacity,
        "charging": charging,
        "status": status,
    }


class TestTelemetryParser(unittest.TestCase):
    """Rigorous unit test suite verifying telemetry logic and edge cases."""

    def test_cpu_stat_normal_calculation(self):
        prev = (1000, 500)
        # Next line has 200 total delta (1200-1000), 50 idle delta (550-500) -> (200-50)/200 = 75%
        line = "cpu  500 0 150 550 0 0 0 0"
        usage, next_stat = parse_cpu_stat(prev, line)
        self.assertAlmostEqual(usage, 75.0, delta=1.0)
        self.assertEqual(next_stat[1], 550)

    def test_cpu_stat_zero_delta_edge_case(self):
        prev = (2000, 1000)
        line = "cpu  500 0 500 1000 0 0 0 0"
        usage, next_stat = parse_cpu_stat(prev, line)
        self.assertEqual(usage, 0.0)

    def test_cpu_stat_malformed_input(self):
        with self.assertRaises(ValueError):
            parse_cpu_stat((0, 0), "not_a_cpu_line 1 2 3")
        with self.assertRaises(ValueError):
            parse_cpu_stat((0, 0), "")

    def test_meminfo_standard_calculation(self):
        sample = """
        MemTotal:       16384000 kB
        MemFree:         4096000 kB
        MemAvailable:    8192000 kB
        Buffers:          500000 kB
        """
        res = parse_meminfo(sample)
        self.assertEqual(res["total_mb"], 16000.0)
        self.assertEqual(res["used_mb"], 8000.0)
        self.assertEqual(res["percent"], 50.0)

    def test_meminfo_empty_or_zero_total(self):
        res = parse_meminfo("MemTotal: 0 kB\nMemAvailable: 0 kB")
        self.assertEqual(res["percent"], 0.0)
        with self.assertRaises(ValueError):
            parse_meminfo("")

    def test_battery_desktop_no_battery(self):
        res = parse_battery_info(None, None)
        self.assertFalse(res["has_battery"])
        self.assertEqual(res["percentage"], 0)
        self.assertFalse(res["charging"])

    def test_battery_laptop_charging(self):
        res = parse_battery_info("87\n", "Charging\n")
        self.assertTrue(res["has_battery"])
        self.assertEqual(res["percentage"], 87)
        self.assertTrue(res["charging"])

    def test_battery_out_of_bounds_clamping(self):
        res = parse_battery_info("145\n", "Discharging\n")
        self.assertEqual(res["percentage"], 100)
        self.assertFalse(res["charging"])

        res_neg = parse_battery_info("-20\n", "Discharging\n")
        self.assertEqual(res_neg["percentage"], 0)


if __name__ == "__main__":
    unittest.main()
