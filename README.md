# WS2805 RGBWW LED Controller for PicoMite

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%20Pico-red.svg)

Offline control for WS2805 RGBWW based LED strings using Raspberry Pi Pico with MMBasic (PicoMite). Originally created to replace the IoT controller in LSC Smart Connect party lights from Action stores(or similar light strings using the same chips).

## 🎯 Why This Project?

Many cheap LED light strings (like LSC Smart Connect from Action/Jumbo stores) require:
- Installing proprietary apps
- Connecting to WiFi
- Sending your lighting data to unknown servers
- Dealing with privacy concerns and potential security vulnerabilities

This project lets you:
- ✅ Control your lights completely offline
- ✅ Use a simple IR remote instead of an app
- ✅ Add custom effects and colors
- ✅ Keep your data private
- ✅ Learn about LED protocols and embedded hacking

## 🔧 Hardware Requirements

### Essential Components
- **Raspberry Pi Pico** (or compatible RP2040 board)
- **PicoMite firmware** ([download here](https://geoffg.net/picomite.html))
- **A suitable 5v regulator**(usually a buck converter module board from amazon is more than enough for the pico)
- **WS2805 LED string** (15 LEDs, 40-bit RGBWW protocol)
- **24V power supply** (usually included with original lights)
- **IR receiver module** (e.g., TSOP4838, VS1838B - optional but recommended)
- **A IR remote control**(i used one that i had laying around in my junk bin)

### Target Hardware
This was specifically designed for **LSC Smart Connect outdoor party lights** available at Action stores (Europe), but should work with any WS2805 RGBWW LED string.

## 📐 Wiring Diagram

```
┌─────────────────┐
│  24V PSU        │
└────┬────────┬───┘
     │        │
     │        └──────────────┐
     │                       │
┌────▼─────┐           ┌─────▼────────────────┐
│  5V Reg  │           │  LED String (24V)    │
│          │           │   ┌─┐  ┌─┐  ┌─┐      │
│          │           │   │L│──│L│──│L│─ ... │
└────┬─────┘           │   └─┘  └─┘  └─┘      │
     │                 └──────▲───────────────┘
     │                        │ Data
┌────▼────────────┐           │
│  Raspberry Pi   │           │
│  Pico           │           │
│                 │           │
│  GP1 (Pin 2) ───┼───────────┘
│  GP2 (Pin 4) ───┼───── IR Receiver (optional)
│  GND ───────────┼───── Common Ground
│  VSYS ──────────┼───── 5V from regulator
└─────────────────┘
```

### Pin Configuration
- **GP1**: LED data line (3.3V logic to WS2805 string)
- **GP2**: IR receiver input (optional)
- **24V**: Powers the LED string directly
- **5V**: Powers the Pico (from existing regulator in controller box)

⚠️ **Important**: The WS2805 LEDs run at 24V internally, but the data line is 5V logic tolerant. The Pico's 3.3V output usually works fine, but if you experience issues, add a 74HCT245 level shifter.

## 🧠 The Technical Challenge

### WS2805 vs WS2812 Protocol Mismatch

The WS2805 uses a **40-bit RGBWW protocol** (8 bits each: Red, Green, Blue, Warm White, Cool White), while PicoMite's built-in `WS2812` command only supports:
- 24-bit RGB (standard WS2812)
- 32-bit RGBW (SK6812)

### The Solution: Virtual LED Mapping

We trick the `WS2812` command by treating **15 physical RGBWW LEDs as 25 virtual RGB LEDs**:
- 15 LEDs × 40 bits = 600 bits total
- 25 LEDs × 24 bits = 600 bits total

However, the byte boundaries don't align cleanly, creating three different interlacing patterns that repeat every 3 LEDs:

#### Pattern 1: LEDs 0, 3, 6, 9, 12 (Clean Alignment)
```
Virtual LED n:   [R G B]
Virtual LED n+1: [W1 W2 R_next]
```

#### Pattern 2: LEDs 1, 4, 7, 10, 13 (1-byte Offset)
```
Virtual LED n:   [? R G]
Virtual LED n+1: [B W1 W2]
```

#### Pattern 3: LEDs 2, 5, 8, 11, 14 (2-byte Offset)
```
Virtual LED n:   [? ? R]
Virtual LED n+1: [G B W1]
Virtual LED n+2: [W2 ? ?]
```

The code handles this interlacing automatically in the `set_color()` and `set_color_raw()` functions.

## 🚀 Installation

### 1. Flash PicoMite Firmware
1. Download PicoMite firmware from [geoffg.net](https://geoffg.net/picomite.html)
2. Hold BOOTSEL button on Pico while plugging into USB
3. Copy the `.uf2` file to the Pico drive
4. Pico will reboot with MMBasic

### 2. Upload the Code
1. Connect to Pico via serial terminal (115200 baud)
2. Copy and paste the code from `ws2805_controller.bas`
3. Type `SAVE "ws2805.bas"` to save permanently
4. Type `RUN` to start
5. Check your IR mapping(see below).
6. When finishing tweaking the code, do not forget to type OPTION AUTORUN ON so the code starts executing directly on powerup.


### 3. Hardware Installation
1. Open the original LSC controller box
2. Identify the SoC (system-on-chip) that handles WiFi
3. Desolder or cut the data line from the SoC
4. Connect the data line to Pico GP1
5. Connect Pico ground to controller ground
6. Connect Pico VSYS to the 5V regulator output
7. (Optional) Add IR receiver to GP2

## 🎮 Features

### Built-in Effects
1. **Static Colors** - 14 preset colors including:
   - RGB primaries and secondaries
   - Warm white, cool white, neutral white
   - Orange, light blue, light green, violet

2. **Rainbow Chase** - Smooth rainbow animation cycling through all LEDs

3. **Color Fade** - Smooth transitions between red, green, and blue

4. **Warm Glow** - Candle-like flickering effect using warm white channel

### IR Remote Control

Default button mapping (customize in `check_ir()` function):

| Button | Function |
|--------|----------|
| Power/Off | Turn all LEDs off |
| Color buttons | Set static colors (14 options) |
| Brightness Up | +10% (or +1% below 10%) |
| Brightness Down | -10% (or -1% below 20%) |
| Mode/Effect | Cycle through effects |

### Smart Brightness Control
- **Fine control** at low levels: Below 10%, brightness adjusts by 1% instead of 10%
- Brightness range: 1-100% (0 = off via color selection)
- All effects respect global brightness setting

## 📝 Code Structure

```
ws2805_controller.bas
├── Configuration constants (pins, LED count)
├── Global variables (brightness, current mode, color table)
├── Initialization (pin setup, IR configuration)
├── Main loop (effect execution, IR polling)
├── LED Control Functions
│   ├── set_color() - Set LED using color table with byte interlacing
│   ├── set_color_raw() - Set LED using raw RGBWW values
│   ├── parse_colors() - Convert byte array to WS2812 format
│   ├── clear_all() - Turn off all LEDs
│   ├── set_all() - Set all LEDs to same color
│   └── set_brightness() - Adjust global brightness
├── Effects
│   ├── rainbow_chase() - Animated rainbow
│   ├── color_fade() - Smooth color transitions
│   └── warm_glow() - Flickering candle effect
└── IR Remote Handler
    └── check_ir() - Process IR remote commands
```

## 🎨 Customization

### Adding New Colors

Edit the `color_table` array (format: G, R, B, W1, W2 per color):

```basic
Dim color_table(69) = (
  0,0,0,0,0,      ' 0: Black (off)
  0,0,0,255,0,    ' 1: Cold white
  0,0,0,0,255,    ' 2: Warm white
  ' Add your colors here...
)
```

### Adding New Effects

Create a new subroutine and add it to the effect selector:

```basic
Sub my_custom_effect()
  ' Your effect code here
  Local i
  For i = 0 To LED_COUNT - 1
    set_color_raw(i, r, g, b, w1, w2)
  Next i
  parse_colors()
End Sub

' Add to main loop:
Select Case current_effect%
  Case 0: ' Static
  Case 1: rainbow_chase()
  Case 2: color_fade()
  Case 3: warm_glow()
  Case 4: my_custom_effect()  ' New effect
End Select
```

### Mapping Your IR Remote

1. Run the program (see Installation section)
2. Press each button and note the device code and key code
3. Update the `check_ir()` function with your codes:

```basic
If devcode = YOUR_DEVICE_CODE Then
  Select Case keycode
    Case YOUR_KEY_CODE: set_all(1)  ' Map to warm white
    ' Add more mappings...
  End Select
EndIf
```

## 🐛 Troubleshooting

### LEDs don't light up at all
- Check 24V power supply is connected and on
- Verify common ground between Pico and LED string
- Confirm data line is connected to GP1
- Try adding a 330Ω resistor in series with data line

### Wrong colors or flickering
- WS2805 may require 5V logic - add a level shifter (74HCT245)
- Check that LED_COUNT matches your actual LED count
- Verify 24V power supply has sufficient current (15 LEDs × ~60mA = 900mA minimum)

### IR remote doesn't work
- Confirm IR receiver is wired correctly (VCC, GND, OUT)
- Check IR receiver is receiving (most have a visible LED that blinks)
- Run IR sniffer code to verify your remote's protocol and codes
- Try different IR receiver modules (TSOP4838, VS1838B, etc.)

### Brightness control doesn't work on static colors
- Make sure you're using the latest code version
- Brightness is applied in `set_color()` - verify this function is correct
- Check that `current_mode%` is set to 0 when selecting static colors

## 📚 Technical References

- [WS2805 Datasheet](https://www.superlightingled.com/PDF/SPEC/WS2814-RGBW-Datasheet.pdf) (Note: WS2814 and WS2805 use identical protocols)
- [PicoMite Manual](https://geoffg.net/Downloads/picomite/PicoMite_User_Manual.pdf)
- [WS2812 Protocol Timing](https://cdn-shop.adafruit.com/datasheets/WS2812.pdf)

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- More effects (strobe, theater chase, etc.)
- Touch sensor support as alternative to IR
- Web interface via Pico W
- MQTT integration for Home Assistant
- Configuration UI via serial terminal
- Support for different LED counts

## 📄 License

MIT License - feel free to use, modify, and distribute.

## 🙏 Acknowledgments

- **Geoff Graham** for PicoMite and excellent MMBasic documentation
- **Action/LSC** for making hackable hardware (even if unintentionally)
- The maker community for reverse engineering knowledge and tools

## ⚠️ Disclaimer

This project involves modifying consumer electronics and working with 24V power supplies. Proceed at your own risk. The author is not responsible for any damage to equipment or injury. Always disconnect power before working on electronics, and ensure proper insulation of all connections.

---

**Built with ❤️ and a healthy distrust of IoT**

Found this useful? Give it a ⭐️ and share with others escaping the cloud!