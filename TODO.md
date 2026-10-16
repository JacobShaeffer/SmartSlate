# SmartSlate UI

- [x] Main screen: Production | Settings, Scene | Take, Roll | Date,
  Notes | MOS/SYNC.
- [x] Settings button uses a gear and opens the settings screen.
- [x] MOS/SYNC is display-only toggle state.
- [x] Settings screen includes a dark/light appearance toggle.
- [x] Settings screen controls the Waveshare display with Linux DDC/CI
  (`ddcutil getvcp 10` / `ddcutil setvcp 10 <0-100>`). The control stays
  disabled unless the physical display returns a valid brightness value.
- [x] Date input uses a numeric `MM/DD/YY` mask.
- [x] Scene and Take open on the numpad while retaining letter input support.

Reference: https://www.waveshare.com/wiki/8DP-CAPLCD#Linux_Software_Brightness_Adjustment
