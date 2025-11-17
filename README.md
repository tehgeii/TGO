# TGO - Tech Gameplay Optimizer

[![Downloads](https://img.shields.io/github/downloads/tehgeii/TGO/total?color=green&label=Downloads)](https://github.com/tehgeii/TGO/releases)
[![Latest Release Downloads](https://img.shields.io/github/downloads/tehgeii/TGO/latest/total?color=green&label=Downloads@Latest)](https://github.com/tehgeii/TGO/releases/latest)
[![Version](https://img.shields.io/badge/Version-1.0.1-blue.svg)](https://github.com/tehgeii/TGO/releases)

TGO is a small Windows batch tool that applies simple tweaks to make Windows feel snappier and improve input responsiveness for gaming.

Quick facts
- Run as Administrator (the script will try to relaunch itself with elevation if needed).
- It changes registry keys, services, and power settings — this can affect your system. **Be careful.**
- Make a System Restore point before running. The script has a menu option to create one.

What the script can do
- **System Restore**: create a restore point or open System Restore.
- **Clean Temp**: remove temp files, clear update cache, run Disk Cleanup and TRIM.
- **Disk Optimization**: different tweaks for HDD or SSD (registry + fsutil changes).
- **Mouse & Keyboard**: Low/Medium/High presets that change device queue sizes, driver priorities, power flags, and input settings. Has a revert option.
- **RAM**: presets or custom input to set service split thresholds and memory compression. Has a revert option.
- **Startup Optimization**: downloads and opens Sysinternals Autoruns so you can disable startup apps (manual step).
- **Power Saving**: disable hibernate/sleep/device power saving or revert to defaults.
- **Exit**: quit the script.

How to run
1. Get and download `TGO.bat` from the [**latest release**](https://github.com/tehgeii/TGO/releases).
2. Right-click `TGO.bat` and choose "Run as administrator".
3. Use the on-screen menu to pick an option and follow any prompts.
4. Restart your PC for changes to take effect.

Is this a virus?
- Short answer: **No.** - this is an open batch script that edits system settings. It's not an installer or obfuscated binary.
- However, because it changes the registry and services, some antivirus engines may flag it as suspicious. Check the VirusTotal report here: https://www.virustotal.com/gui/file/a3efed5b37f08be0ab1ca79e158c6ee54473170ad5b18325dfc8ce5fd74ee636

Before Using TGO
- The script includes revert options for some areas and a System Restore creator, but some changes may require a reboot or manual undo.
- [**Review the batch script**](./TGO.bat) if you're curious about what changes are made.
- If unsure, **create a restore point first.**
- Watch [**here**](https://youtu.be/kOw1KssCeN0) for the guide.

Performance Improvements
- Available in the [`Comparison`](./Comparison).

Support
- Open an [issue](https://github.com/tehgeii/TGO/issues) in this repo if something goes wrong or if you want improvements.
#
<div align="center">

**TGO – Make Windows faster and smooth!**

[Download Latest Release](https://github.com/tehgeii/TGO/releases) | [Report Issue](https://github.com/tehgeii/TGO/issues)

*Made with ❤️ for the Windows community*

</div>
