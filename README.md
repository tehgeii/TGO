# TGO — Tech Gameplay Optimizer (TGO.bat)

[![Downloads](https://img.shields.io/github/downloads/tehgeii/TGO/total?color=green&label=Downloads)](https://github.com/tehgeii/TGO/releases)

TGO.bat is a small Windows batch tool (v1.0) that applies simple tweaks to make Windows feel snappier and improve input responsiveness for gaming.

Quick facts
- Run as Administrator (the script will try to relaunch itself with elevation if needed).
- It changes registry keys, services, and power settings — this can affect your system. Be careful.
- Make a System Restore point before running. The script has a menu option to create one.

What the script can do (menu overview)
- System Restore: create a restore point or open System Restore.
- Clean Temp: remove temp files, clear update cache, run Disk Cleanup and TRIM.
- Disk Optimization: different tweaks for HDD or SSD (registry + fsutil changes).
- Mouse & Keyboard: Low/Medium/High presets that change device queue sizes, driver priorities, power flags, and input settings. Has a revert option.
- RAM: presets or custom input to set service split thresholds and memory compression. Has a revert option.
- Startup: downloads and opens Sysinternals Autoruns so you can disable startup apps (manual step).
- Power Saving: disable hibernate/sleep/device power saving or revert to defaults.
- Exit: quit the script.

How to download
- Download TGO.bat from the Releases section (on the right side of this repo page) or clone the repository.

How to run
1. Get TGO.bat (Releases or clone).
2. Right-click TGO.bat and choose "Run as administrator" (or run it from an elevated Command Prompt).
3. Use the on-screen menu to pick an option and follow any prompts.

Is this a virus?
- Short answer: No — this is an open batch script that edits system settings. It's not an installer or obfuscated binary.
- However, because it changes the registry and services, some antivirus engines may flag it as suspicious. Check the VirusTotal report here:
  https://www.virustotal.com/gui/file/eb3d627bb43f07f6500266b5695ff0f71a2254d31200ac503fc34339035cf5f2
- If you see detections, inspect the script yourself or run it in a sandbox/VM. Creating a restore point before running is recommended.

Safety & revert
- The script includes revert options for some areas and a System Restore creator, but some changes may require a reboot or manual undo.
- If unsure, create a restore point or back up the registry first.

Support
- Open an issue in this repo if something goes wrong or if you want improvements.
