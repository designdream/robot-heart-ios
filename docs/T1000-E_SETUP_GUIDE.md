# SenseCAP T1000-E Setup Guide for Robot Heart

This guide covers setting up your SenseCAP T1000-E tracker for use with the Robot Heart iOS app.

---

## Device Specifications

| Spec | Details |
|------|---------|
| **MCU** | Nordic nRF52840 (Bluetooth 5.0) |
| **LoRa Chip** | Semtech LR1110 |
| **Frequency** | 865-928 MHz (US: 902-928 MHz) |
| **GPS** | Mediatek AG3335 |
| **Battery** | 700mAh rechargeable lithium |
| **Size** | Credit card size |
| **Rating** | IP65 (waterproof/dustproof) |
| **Charging** | USB magnetic pogo pins |

---

## Before You Start

### What You Need
- SenseCAP T1000-E (Meshtastic version)
- USB magnetic charging cable (included)
- iPhone with Robot Heart app installed
- Meshtastic iOS app (for initial setup)

### Important Warnings

⚠️ **DO NOT** manually reboot or turn off the device while:
- Messages are being transmitted
- Device is being configured

⚠️ **DO NOT** use fast-charging chargers - use standard 5V chargers only

⚠️ **DO NOT** use NRF-OTA to update firmware - it can brick the device

---

## Step 1: Charge Your Device

1. Connect the magnetic USB cable to the pogo pins on the back
2. Charge until the LED turns solid green
3. First charge: allow 2-3 hours for full charge

---

## Step 2: Power On

1. **Press the button once** to power on
2. You'll hear a **rising melody**
3. LED will stay on for ~1 second
4. Device is now in pairing mode

**If device doesn't respond:** Charge it first. The battery may be depleted from shipping.

---

## Step 3: Connect via Meshtastic App (Initial Setup)

For first-time setup, use the official Meshtastic iOS app:

1. Download **Meshtastic** from the App Store
2. Open the app and go to Bluetooth settings
3. Look for device named `Meshtastic_XXXX` or `T1000-E_XXXX`
4. Select your device
5. Enter PIN: **`123456`** (default)
6. Tap OK to connect

---

## Step 4: Configure Region (CRITICAL)

You MUST set your region before the device will work:

1. In Meshtastic app, go to **Settings > LoRa**
2. Set **Region** to: **US** (for Burning Man)
3. This sets frequency to 902-928 MHz

| Region | Frequency | Use For |
|--------|-----------|---------|
| US | 902-928 MHz | United States, Burning Man |
| EU_868 | 869.4-869.65 MHz | European Union |

---

## Step 5: Configure for Robot Heart

### Recommended Settings

| Setting | Value | Why |
|---------|-------|-----|
| **Device Name** | Your playa name | Identification |
| **Region** | US | Burning Man is in Nevada |
| **Hop Limit** | 3 | Good mesh coverage |
| **Position Broadcast** | 15 min | Battery vs accuracy |
| **GPS Mode** | Enabled | Location tracking |

### Channel Setup

For Robot Heart camp mesh:
1. Go to **Channels**
2. Add channel: `RobotHeart`
3. Set encryption key (will be provided by camp leads)

---

## Step 6: Connect to Robot Heart App

Once configured in Meshtastic app:

1. Open **Robot Heart** app
2. Go to **Settings** (gear icon)
3. Tap **Connect** under Meshtastic Connection
4. Select your T1000-E device
5. You should see "Connected" status

---

## LED Status Indicators

| LED Pattern | Meaning |
|-------------|---------|
| **Solid Green** | Charging / DFU mode |
| **Blinking Green** | GPS searching |
| **Solid Blue** | Bluetooth connected |
| **Blinking Blue** | Bluetooth advertising |
| **Red Flash** | Low battery |
| **No LED** | Powered off or dead battery |

---

## Button Functions

| Action | Result |
|--------|--------|
| **Single press** | Power on (when off) |
| **Single press** | Send position update (when on) |
| **Long press (3s)** | Power off |
| **Long press (10s)** | Factory reset |
| **Press while connecting USB** | Enter DFU mode |

---

## Known Issues & Workarounds

### Issue 1: LR1110 Compatibility with SX127x Radios

**Problem:** T1000-E uses LR1110 chip which cannot receive packets from older SX127x radios directly.

**Workaround:** 
- Transmitting works fine
- When hopping through an SX126x radio, you can still receive from SX127x
- Most modern Meshtastic devices use SX126x, so this is rarely an issue

### Issue 2: Firmware Update Hangs (v2.5.9+)

**Problem:** Firmware updates via drag-and-drop to T1000-E drive may hang on versions 2.5.9+

**Workaround:**
1. Use the [Meshtastic Web Flasher](https://flasher.meshtastic.org/) instead
2. Connect via USB
3. Select "Seeed Card Tracker T1000-E"
4. Flash the firmware

### Issue 3: Bluetooth Not Visible

**Problem:** Device not appearing in Bluetooth scan

**Workaround:**
1. Ensure you're using **Companion firmware** (not Repeater)
2. Repeater firmware disables Bluetooth
3. Reboot the device (long press 3s, then single press)
4. If still not visible, perform factory reset

### Issue 4: External Notifications Stop After Firmware Update

**Problem:** Buzzer stops working after updating from factory firmware

**Status:** Known bug in Meshtastic firmware. The beep function was hardcoded in factory firmware.

**Workaround:** Currently no fix. Use visual LED indicators instead.

### Issue 5: Device Bricked / Won't Boot

**Problem:** Device stuck in boot loop or won't turn on

**Recovery Steps:**
1. Connect USB while holding button (enter DFU mode)
2. Green LED should be solid
3. Use [Meshtastic Web Flasher](https://flasher.meshtastic.org/)
4. Perform "Full Erase" first
5. Then flash latest firmware

If that fails:
1. Disconnect USB
2. Leave device for several days until battery fully drains
3. Reconnect and try again

### Issue 6: GPS Not Getting Fix

**Problem:** GPS takes very long or never gets a fix

**Workaround:**
- Go outside with clear sky view
- First fix can take 5-10 minutes
- Subsequent fixes are faster (warm start)
- On playa: dust storms may affect GPS accuracy

---

## Firmware Updates

### Check Current Version
1. Open Meshtastic app
2. Connect to device
3. Go to Settings > Device
4. Note the firmware version

### Update Firmware

**Recommended Method: Web Flasher**
1. Go to [flasher.meshtastic.org](https://flasher.meshtastic.org/)
2. Connect T1000-E via USB
3. Select device: "Seeed Card Tracker T1000-E"
4. Choose latest stable firmware
5. Click Flash

**DO NOT use:**
- NRF-OTA (can brick device)
- Drag-and-drop for v2.5.9+ (may hang)

---

## Factory Reset

If you need to start fresh:

**Method 1: App**
1. Open Meshtastic app
2. Go to Settings
3. Tap "Factory Reset"
4. Device will reboot with default settings

**Method 2: Button**
1. Long press button for 10+ seconds
2. Device will reset and reboot

**Method 3: Full Erase (if device is stuck)**
1. Enter DFU mode (hold button while connecting USB)
2. Use Web Flasher
3. Select "Full Erase"
4. Re-flash firmware

---

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Won't turn on | Charge for 2+ hours |
| Not in Bluetooth list | Reboot device, check firmware type |
| Can't connect | Default PIN is `123456` |
| No GPS fix | Go outside, wait 5-10 min |
| Messages not sending | Check region is set to US |
| Device rebooting randomly | Flash erase + reinstall firmware |
| Buzzer not working | Known bug after firmware update |

---

## Signal Quality Reference

| Metric | Good | Poor |
|--------|------|------|
| **SNR** | > -7 dB | < -10 dB |
| **RSSI** | > -110 dBm | < -115 dBm |

For best signal on playa:
- Keep device in open area
- Avoid metal containers
- Higher elevation = better range

---

## Battery Life Tips

Expected battery life: **5-7 days** on playa

To maximize:
- Reduce position broadcast interval (30 min vs 15 min)
- Disable GPS when not needed
- Keep device cool (avoid direct sun)
- Use power-saving mode if available

---

## Resources

- [Seeed Studio Wiki](https://wiki.seeedstudio.com/sensecap_t1000_e/)
- [Meshtastic Docs](https://meshtastic.org/docs/hardware/devices/seeed-studio/sensecap/card-tracker/)
- [Meshtastic Web Flasher](https://flasher.meshtastic.org/)
- [Meshtastic iOS App](https://apps.apple.com/app/meshtastic/id1586432531)

---

## Support

If you have issues:
1. Check this guide first
2. Ask in the Robot Heart camp Slack/Discord
3. Contact Seeed Studio: support@sensecapmx.com

---

*Last updated: January 2026*
*For Robot Heart Camp - Burning Man*
