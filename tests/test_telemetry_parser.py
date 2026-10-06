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


def parse_net_dev(content: str, prev_bytes: Tuple[int, int], dt_sec: float) -> Tuple[Dict[str, object], Tuple[int, int]]:
    """
    Parses /proc/net/dev content, ignoring 'lo', summing non-loopback interfaces.
    Returns ({'rx_rate_bytes': float, 'tx_rate_bytes': float, 'speed_str': str}, (curr_rx, curr_tx))
    """
    if not content:
        return {"rx_rate_bytes": 0.0, "tx_rate_bytes": 0.0, "speed_str": "0 KB/s"}, prev_bytes

    total_rx = 0
    total_tx = 0
    for line in content.strip().splitlines():
        if ":" not in line:
            continue
        iface, data = line.split(":", 1)
        iface = iface.strip()
        if iface == "lo":
            continue
        parts = data.split()
        if len(parts) >= 9:
            try:
                total_rx += int(parts[0])
                total_tx += int(parts[8])
            except ValueError:
                continue

    prev_rx, prev_tx = prev_bytes
    if prev_rx == 0 and prev_tx == 0:
        return {"rx_rate_bytes": 0.0, "tx_rate_bytes": 0.0, "speed_str": "0 KB/s"}, (total_rx, total_tx)

    delta_sec = max(0.1, dt_sec)
    rx_delta = max(0, total_rx - prev_rx)
    tx_delta = max(0, total_tx - prev_tx)
    rx_rate = rx_delta / delta_sec
    tx_rate = tx_delta / delta_sec

    def fmt_speed(bps: float) -> str:
        if bps >= 1024 * 1024:
            return f"{bps / (1024 * 1024):.1f} MB/s"
        elif bps >= 1024:
            return f"{int(bps / 1024)} KB/s"
        else:
            return f"{int(bps)} B/s"

    speed_str = f"↓ {fmt_speed(rx_rate)}  ↑ {fmt_speed(tx_rate)}"
    return {
        "rx_rate_bytes": rx_rate,
        "tx_rate_bytes": tx_rate,
        "speed_str": speed_str,
    }, (total_rx, total_tx)


def parse_intel_rc6(rc6_str: Optional[str], prev_rc6: int, dt_ms: int) -> Tuple[float, int]:
    """
    Calculates Intel GPU busy percentage from /sys/class/drm/card*/power/rc6_residency_ms.
    Returns (gpu_usage_percent, current_rc6_ms)
    """
    if not rc6_str:
        return 0.0, prev_rc6

    try:
        curr_rc6 = int(rc6_str.strip())
    except ValueError:
        return 0.0, prev_rc6

    if prev_rc6 <= 0 or dt_ms <= 0:
        return 0.0, curr_rc6

    rc6_delta = max(0, curr_rc6 - prev_rc6)
    idle_fraction = min(1.0, rc6_delta / float(dt_ms))
    busy_percent = max(0.0, min(100.0, round((1.0 - idle_fraction) * 100.0, 1)))
    return busy_percent, curr_rc6


def parse_serial_device(device_str: Optional[str]) -> str:
    """
    Cleans serial port identifier into human readable form.
    Returns 'Sin conexión' if empty/None.
    """
    if not device_str or not device_str.strip():
        return "Sin conexión"
    s = device_str.strip()
    if s.startswith("/dev/"):
        s = s[5:]
    if s.startswith("serial/by-id/"):
        s = s[len("serial/by-id/"):]
    if s.startswith("usb-"):
        s = s[4:]
    return s


class TestTelemetryParser(unittest.TestCase):
    """Rigorous unit test suite verifying telemetry logic and edge cases."""

    def test_cpu_stat_normal_calculation(self):
        prev = (1000, 500)
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

    def test_network_speed_normal_calculation(self):
        sample = """
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:   20000     200    0    0    0     0          0         0    20000     200    0    0    0     0       0          0
  wlo1: 10485760  10000    0    0    0     0          0         0  1048576    2000    0    0    0     0       0          0
"""
        # Previous was (0, 0) -> init
        res, state = parse_net_dev(sample, (0, 0), 2.0)
        self.assertEqual(state, (10485760, 1048576))

        # Next sample: 2MB received and 512KB transmitted over 2.0s -> 1MB/s down, 256KB/s up
        next_sample = """
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:   25000     250    0    0    0     0          0         0    25000     250    0    0    0     0       0          0
  wlo1: 12582912  11000    0    0    0     0          0         0  1572864    2500    0    0    0     0       0          0
"""
        res, state2 = parse_net_dev(next_sample, state, 2.0)
        self.assertAlmostEqual(res["rx_rate_bytes"], 1048576.0, delta=10)
        self.assertIn("1.0 MB/s", res["speed_str"])
        self.assertIn("256 KB/s", res["speed_str"])

    def test_intel_rc6_calculation(self):
        # 1000ms elapsed, rc6 delta is 600ms -> busy was 40%
        busy, curr = parse_intel_rc6("1600", 1000, 1000)
        self.assertEqual(busy, 40.0)
        self.assertEqual(curr, 1600)

        # 100% idle
        busy_idle, _ = parse_intel_rc6("2000", 1000, 1000)
        self.assertEqual(busy_idle, 0.0)

        # 100% busy (0 rc6 delta)
        busy_full, _ = parse_intel_rc6("1000", 1000, 1000)
        self.assertEqual(busy_full, 100.0)

    def test_serial_device_parsing(self):
        self.assertEqual(parse_serial_device(None), "Sin conexión")
        self.assertEqual(parse_serial_device(""), "Sin conexión")
        self.assertEqual(parse_serial_device("/dev/ttyUSB0"), "ttyUSB0")
        self.assertEqual(parse_serial_device("/dev/serial/by-id/usb-FTDI_FT232R-if00"), "FTDI_FT232R-if00")
        self.assertEqual(parse_serial_device("usb-Arduino_LLC_Arduino_Uno-if00"), "Arduino_LLC_Arduino_Uno-if00")


if __name__ == "__main__":
    unittest.main()

