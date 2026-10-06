#!/usr/bin/env python3
"""
Unit tests for wifi_manager.py parsing and edge cases.
"""

import unittest
from scripts.wifi_manager import parse_nmcli_wifi_list


class TestWifiManager(unittest.TestCase):
    def test_parse_empty_output(self):
        self.assertEqual(parse_nmcli_wifi_list(""), [])
        self.assertEqual(parse_nmcli_wifi_list("   \n\n  "), [])

    def test_parse_standard_multiline_output(self):
        sample = """
IN-USE:                                 *
SSID:                                   Home_Wifi_5G
SIGNAL:                                 85
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   CoffeeShop_Guest
SIGNAL:                                 62
SECURITY:                               WPA1 WPA2
IN-USE:                                  
SSID:                                   FreePublicWifi
SIGNAL:                                 45
SECURITY:                               
"""
        nets = parse_nmcli_wifi_list(sample)
        self.assertEqual(len(nets), 3)

        # First must be the connected one
        self.assertTrue(nets[0]["inUse"])
        self.assertEqual(nets[0]["ssid"], "Home_Wifi_5G")
        self.assertEqual(nets[0]["signal"], 85)
        self.assertEqual(nets[0]["security"], "WPA2")

        # Second should be CoffeeShop_Guest
        self.assertFalse(nets[1]["inUse"])
        self.assertEqual(nets[1]["ssid"], "CoffeeShop_Guest")
        self.assertEqual(nets[1]["signal"], 62)

        # Third is open network
        self.assertFalse(nets[2]["inUse"])
        self.assertEqual(nets[2]["ssid"], "FreePublicWifi")
        self.assertEqual(nets[2]["security"], "")

    def test_deduplication_prefers_in_use_and_higher_signal(self):
        sample = """
IN-USE:                                  
SSID:                                   MeshNetwork
SIGNAL:                                 50
SECURITY:                               WPA2
IN-USE:                                 *
SSID:                                   MeshNetwork
SIGNAL:                                 40
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   OtherNetwork
SIGNAL:                                 30
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   OtherNetwork
SIGNAL:                                 75
SECURITY:                               WPA2
"""
        nets = parse_nmcli_wifi_list(sample)
        self.assertEqual(len(nets), 2)

        # MeshNetwork is inUse, so inUse=True must be preserved even if another BSSID had 50 signal
        mesh = next(n for n in nets if n["ssid"] == "MeshNetwork")
        self.assertTrue(mesh["inUse"])

        # OtherNetwork should have kept the higher signal (75)
        other = next(n for n in nets if n["ssid"] == "OtherNetwork")
        self.assertEqual(other["signal"], 75)

    def test_ignore_empty_or_hidden_ssid(self):
        sample = """
IN-USE:                                  
SSID:                                   --
SIGNAL:                                 90
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   
SIGNAL:                                 80
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   ValidSSID
SIGNAL:                                 70
SECURITY:                               WPA2
"""
        nets = parse_nmcli_wifi_list(sample)
        self.assertEqual(len(nets), 1)
        self.assertEqual(nets[0]["ssid"], "ValidSSID")

    def test_signal_clamping(self):
        sample = """
IN-USE:                                  
SSID:                                   OverSignal
SIGNAL:                                 150
SECURITY:                               WPA2
IN-USE:                                  
SSID:                                   NegativeSignal
SIGNAL:                                 -10
SECURITY:                               WPA2
"""
        nets = parse_nmcli_wifi_list(sample)
        self.assertEqual(len(nets), 2)
        over = next(n for n in nets if n["ssid"] == "OverSignal")
        self.assertEqual(over["signal"], 100)
        neg = next(n for n in nets if n["ssid"] == "NegativeSignal")
        self.assertEqual(neg["signal"], 0)


if __name__ == "__main__":
    unittest.main()
