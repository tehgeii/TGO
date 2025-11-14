# TGO — Tech Gameplay Optimizer

**TGO** is a small Windows batch tool that applies simple tweaks to make Windows feel snappier and improve input responsiveness for gaming.

Quick facts
- Run as Administrator (the script will try to relaunch itself with elevation if needed).
- It changes registry keys, services, and power settings — this can affect your system. **Be careful.**
- Make a System Restore point before running. The script has a menu option to create one.

What the script can do (menu overview)
- **System Restore**: create a restore point or open System Restore.
- **Clean Temp**: remove temp files, clear update cache, run Disk Cleanup and TRIM.
- **Disk Optimization**: different tweaks for HDD or SSD (registry + fsutil changes).
- **Mouse & Keyboard**: Low/Medium/High presets that change device queue sizes, driver priorities, power flags, and input settings. Has a revert option.
- **RAM**: presets or custom input to set service split thresholds and memory compression. Has a revert option.
- **Startup Optimization**: downloads and opens Sysinternals Autoruns so you can disable startup apps (manual step).
- **Power Saving**: disable hibernate/sleep/device power saving or revert to defaults.
- **Exit**: quit the script.

How to run
1. Get and download `TGO.bat` from the [latest release](https://github.com/tehgeii/TGO/releases).
2. Right-click `TGO.bat` and choose "Run as administrator".
3. Use the on-screen menu to pick an option and follow any prompts.
4. Restart your PC for changes to take effect

Safety & revert
- The script includes revert options for some areas and a System Restore creator, but some changes may require a reboot or manual undo.
- If unsure, create a restore point first.

Support
- Open an issue in this repo if something goes wrong or if you want improvements.
