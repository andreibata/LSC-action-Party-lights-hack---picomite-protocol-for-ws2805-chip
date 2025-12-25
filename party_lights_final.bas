' ============================================================================
' WS2805 RGBWW LED Controller for PicoMite
' ============================================================================
' Controls 15 WS2805 LEDs (40-bit RGBWW protocol) using WS2812 command hack
' Includes IR remote control and built-in effects
'
' Hardware:
' - GP1 (Pin 2): LED data line
' - GP2 (Pin 4): IR receiver (optional)
' - 24V power supply for LED string
' - Common ground between Pico and LED string
' ============================================================================

Option Explicit
Option Default Integer

' ---------- CONFIGURATION ----------
Const LED_PIN = 1          ' GPIO pin for LED data
Const IR_PIN = 2           ' GPIO pin for IR receiver
Const LED_COUNT = 15       ' Number of WS2805 LEDs in string
Const VIRTUAL_LEDS = 25    ' Virtual WS2812 LEDs (15*5/3)

' ---------- GLOBAL VARIABLES ----------
Dim color_array(LED_COUNT*5)           ' Raw byte array (75 bytes)
Dim led_colors%((LED_COUNT*5)/3)       ' Virtual RGB array for WS2812
Dim brightness% = 100                   ' Global brightness (0-100%)
Dim current_effect% = 0                 ' Current effect mode
Dim ir_code$                            ' Last received IR code
Dim current_mode% = 0
Dim current_color% = 0

'VAR restore

' ---------- COLOR LOOKUP TABLE ----------
' Format: R, G, B, W1(warm), W2(cool) for each color
' Note: WS2805 uses GRB byte order, handled in set_color mapping
'0 - black(all off)
'1 - cold white
'2 - warm white
'3 - green
'4 - red
'5 - blue
'6 - cyan
'7 - magenta
'8 - yellow
'9 - neutral white
'10 - pink
'11 - light green
'12 - light blue
'13 - violet
Dim color_table(69) = (0,0,0,0,0,0,0,0,255,0,0,0,0,0,255,255,0,0,0,0,0,255,0,0,0,0,0,255,0,0,255,0,255,0,0,0,255,255,0,0,255,255,0,0,0,0,0,0,255,255,0,255,0,255,0,255,0,0,255,0,0,0,255,255,0,130,238,238,0,0)

' ---------- INITIALIZATION ----------
SetPin LED_PIN, DOUT
SetPin IR_PIN, IR        ' IR receiver input
Dim integer DevCode,KeyCode

IR devcode,keycode,check_ir

clear_all()
Print "WS2805 Controller Started"
Print "LED Pin: GP"; LED_PIN
Print "IR Pin: GP"; IR_PIN
Print "LED Count: "; LED_COUNT
Print ""

' ---------- MAIN LOOP ----------
Do
  ' Check for IR remote input
  'check_ir()

  ' Run current effect
  Select Case current_effect%
    Case 0: ' Static mode - do nothing
    Case 1: rainbow_chase()
    Case 2: color_fade()
    Case 3: warm_glow()
  End Select

  Pause 50
Loop

' ============================================================================
' LED CONTROL FUNCTIONS
' ============================================================================

' Set individual LED color using color table index (0-8)
Sub set_color(led_nbr, led_color)
  Local base = led_nbr * 5
  Local color_base = led_color * 5

  ' WS2805 byte alignment repeats every 3 LEDs due to 5-byte vs 3-byte mismatch
  ' Three different patterns based on LED position mod 3

  If led_nbr Mod 3 = 0 Then
    ' LEDs 0, 3, 6, 9, 12: Clean alignment - direct mapping
    ' These LEDs start at byte boundaries divisible by 3
    color_array(base)   = (color_table(color_base)*brightness%)\100     ' G
    color_array(base+1) = (color_table(color_base+1)*brightness%)\100   ' R
    color_array(base+2) = (color_table(color_base+2)*brightness%)\100   ' B
    color_array(base+3) = (color_table(color_base+3)*brightness%)\100   ' W1
    color_array(base+4) = (color_table(color_base+4)*brightness%)\100   ' W2

  ElseIf led_nbr Mod 3 = 1 Then
    ' LEDs 1, 4, 7, 10, 13: Offset by 1 byte - data wraps across boundary
    ' Last byte of this LED becomes first byte of next virtual LED
    color_array(base)   = (color_table(color_base+1)*brightness%)\100   ' R
    color_array(base+1) = (color_table(color_base+2)*brightness%)\100   ' B
    color_array(base+2) = (color_table(color_base)*brightness%)\100     ' G
    color_array(base+3) = (color_table(color_base+4)*brightness%)\100   ' W2
    color_array(base+5) = (color_table(color_base+3)*brightness%)\100   ' W1

  Else
    ' LEDs 2, 5, 8, 11, 14: Offset by 2 bytes - heavily interlaced
    ' Data splits across previous and current virtual LED boundaries
    color_array(base-1) = (color_table(color_base+1)*brightness%)\100   ' R (tail of prev LED)
    color_array(base+1) = (color_table(color_base)*brightness%)\100     ' G
    color_array(base+2) = (color_table(color_base+4)*brightness%)\100   ' W2
    color_array(base+3) = (color_table(color_base+2)*brightness%)\100   ' B
    color_array(base+4) = (color_table(color_base+3)*brightness%)\100   ' W1
  EndIf
End Sub

' Set LED using raw RGBW values (0-255) with brightness scaling
Sub set_color_raw(led_nbr, r, g, b, w1, w2)
  Local base = led_nbr * 5

  ' Apply global brightness scaling
  r = (r * brightness%) \ 100
  g = (g * brightness%) \ 100
  b = (b * brightness%) \ 100
  w1 = (w1 * brightness%) \ 100
  w2 = (w2 * brightness%) \ 100

  ' Same alignment patterns as set_color()
  If led_nbr Mod 3 = 0 Then
    color_array(base)   = g
    color_array(base+1) = r
    color_array(base+2) = b
    color_array(base+3) = w1
    color_array(base+4) = w2

  ElseIf led_nbr Mod 3 = 1 Then
    color_array(base)   = r
    color_array(base+1) = b
    color_array(base+2) = g
    color_array(base+3) = w2
    color_array(base+5) = w1

  Else
    color_array(base-1) = r
    color_array(base+1) = g
    color_array(base+2) = w2
    color_array(base+3) = b
    color_array(base+4) = w1
  EndIf
End Sub

' Convert color_array bytes to RGB values and send to LEDs
Sub parse_colors()
  Local i
  For i = 0 To VIRTUAL_LEDS - 1
    led_colors%(i) = RGB(color_array(i*3), color_array(i*3+1), color_array(i*3+2))
  Next i
  WS2812 o, LED_PIN, VIRTUAL_LEDS, led_colors%()
End Sub

' Clear all LEDs (turn off)
Sub clear_all()
  Local i
  For i = 0 To (LED_COUNT*5) - 1
    color_array(i) = 0
  Next i
  parse_colors()
End Sub

' Set all LEDs to same color (table index)
Sub set_all(color_code)
  current_mode% = 0
  current_color% = color_code
  'VAR save current_color%
  Local i
  For i = 0 To LED_COUNT-1
    set_color(i,color_code)
  Next i
  parse_colors()
End Sub


'  Local i
'  For i = 0 To LED_COUNT - 1
'    set_color(i, color_code)
'  Next i
'  parse_colors()
'End Sub

' Set brightness (0-100%)
Sub set_brightness(level)
  brightness% = Max(1, Min(100, level))

  If current_mode% = 0 Then
    set_all(current_color%)
  EndIf

  ' Refresh current colors with new brightness
  'parse_colors()
End Sub

' ============================================================================
' EFFECTS
' ============================================================================

' Rainbow chase effect
Sub rainbow_chase()
  Static hue% = 0
  Local i, r, g, b,h

  For i = 0 To LED_COUNT - 1
    ' Calculate color based on position and hue offset
     h = (hue% + (i * 256 \ LED_COUNT)) Mod 256

    ' Simple HSV to RGB conversion
    If h < 85 Then
      r = h * 3
      g = 255 - h * 3
      b = 0
    ElseIf h < 170 Then
      h = h - 85
      r = 255 - h * 3
      g = 0
      b = h * 3
    Else
      h = h - 170
      r = 0
      g = h * 3
      b = 255 - h * 3
    EndIf

    set_color_raw(i, r, g, b, 0, 0)
  Next i

  parse_colors()
  hue% = (hue% + 2) Mod 256
End Sub

' Fade between colors
Sub color_fade()
  Static phase% = 0
  Static direction% = 1
  Local r, g, b

  ' Fade red -> green -> blue -> red
  If phase% < 85 Then
    r = 255 - phase% * 3
    g = phase% * 3
    b = 0
  ElseIf phase% < 170 Then
    r = 0
    g = 255 - (phase% - 85) * 3
    b = (phase% - 85) * 3
  Else
    r = (phase% - 170) * 3
    g = 0
    b = 255 - (phase% - 170) * 3
  EndIf

  Local i
  For i = 0 To LED_COUNT - 1
    set_color_raw(i, r, g, b, 0, 0)
  Next i

  parse_colors()

  phase% = phase% + direction%
  If phase% >= 255 Or phase% <= 0 Then direction% = -direction%
End Sub

' Warm candle-like glow effect
Sub warm_glow()
  Static flicker% = 0
  Local i, warmth

  For i = 0 To LED_COUNT - 1
    ' Random flicker on each LED
    warmth = 200 + (Rnd() * 55) - flicker%
    warmth = Max(150, Min(255, warmth))
    set_color_raw(i, 0, 0, 0, 0,warmth)
  Next i

  parse_colors()
  flicker% = (flicker% + 1) Mod 20
End Sub

' ============================================================================
' IR REMOTE CONTROL
' ============================================================================

Sub check_ir
  ' Check if IR data available (implement based on your IR receiver protocol)
  ' This is a placeholder - you'll need to adapt to your specific remote
  Print "received device=",devcode," key=",keycode,Chr$(13);


    If devcode = 255 Then
      Select Case keycode
        Case 34     	                        'ON button - set cold white
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(1)
        Case 162				'OFF button - set all off
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(0)
        Case 88					'set all cold white
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(1)
        Case 24					'set all warm white
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(2)
        Case 42					'set all red
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(4)
        Case 170				'set all green
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(3)
        Case 146				'set all blue
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(5)
        Case 56					'set all yellow
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(8)
        Case 184
          current_effect% = 0			'set all cyan
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(6)
        Case 120				'set all magenta
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(7)
        Case 152				'set all neutral white
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(9)
        Case 108				'set all pink
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(10)
        Case 138				'set all light green
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(11)
        Case 178				'set all light blue
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(12)
        Case 508				'set all violet
          current_effect% = 0
          'VAR save current_effect%
          current_mode% = current_effect%
          set_all(13)
        Case 168				'toogle effects
          current_effect% = (current_effect%+1) Mod 4
          current_mode% = current_effect%
          'VAR save current_effect%
        Case 26					'increase brightness
          If brightness% >=10 Then
            set_brightness(brightness% + 10)
            'VAR save brightness%
          Else
            set_brightness(brightness% + 1)
            'VAR save brightness%
          EndIf
        Case 154				'decrease brightness
          If brightness% >=20 Then
            set_brightness(brightness% - 10)
            'VAR save brightness%
          Else
            set_brightness(brightness% - 1)
            'VAR save brightness%
          End If
        End Select
    EndIf




  ' If Len(ir_code$) > 0 Then
  '   Select Case ir_code$
  '     Case "PWR": clear_all()              ' Power off
  '     Case "1": set_all(1)                 ' Warm white
  '     Case "2": set_all(4)                 ' Red
  '     Case "3": set_all(3)                 ' Green
  '     Case "4": set_all(5)                 ' Blue
  '     Case "UP": set_brightness(brightness% + 10)    ' Brightness up
  '     Case "DN": set_brightness(brightness% - 10)    ' Brightness down
  '     Case "EFF": current_effect% = (current_effect% + 1) Mod 4  ' Cycle effects
  '   End Select
  ' EndIf
End Sub

' ============================================================================
' HELPER FUNCTIONS
' ============================================================================

'Function Max_v(a, b)
 ' Local max_val
'  If a > b Then Max_val = a Else Max_val = b
'End Function

'Function Min_v(a, b)
'  Local min_val
'  If a < b Then Min_val = a Else Min_val = b
'End Function