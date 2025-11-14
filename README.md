# TGO — Tech Gameplay Optimizer (TGO.bat)

TGO.bat (Tech Gameplay Optimizer) is a Windows batch script (Version 1.0) that provides a menu-driven set of system maintenance and optimization tasks intended to improve responsiveness and gaming performance. The script performs file cleanup, registry tweaks, service and power configuration, driver/IO priority adjustments, and other changes that can affect system behavior. Many operations require Administrator privileges and can modify system files, Windows services, and the registry. Use with caution and back up your system before applying changes.

## Important Warning

- Always run TGO.bat as Administrator. The script attempts to relaunch itself with elevated privileges if it's not already elevated.
- The script makes significant registry and service changes (disabling services, changing driver priorities, altering power settings, etc.). These changes can affect system stability and behavior.
- Create a system restore point before applying optimizations. The script includes an option to create a restore point and attempts to bypass the 24-hour cooldown rule when creating one.

## Menu (Version 1.0) — Overview of Options

When launched, TGO.bat presents a menu with the following options:

0) System Restore
- Create a system restore point (script uses PowerShell and attempts to bypass the default cooldown).
- Open System Restore (launches rstrui.exe when available; otherwise opens System Protection settings).

1) Clean All Temporary Files
- Cleans Windows and user temp folders, selected system logs, thumbnail caches.
- Stops Windows Update related services and recreates the SoftwareDistribution folder.
- Clears Recycle Bin, runs Disk Cleanup (cleanmgr), and issues a TRIM/Optimize-Volume command for C:.

2) Disk Optimization (choose HDD or SSD)
- HDD Optimization:
  - Adjusts per-device registry parameters (e.g., UserWriteCacheSetting, CacheIsPowerProtected).
  - Applies fsutil/NTFS tweaks: memory usage, last access disabling, delete notify, paging file encryption, MFT zone, 8.3 name creation.
  - Disables Prefetch/Prefetcher in the registry and disables SysMain (Superfetch) service.
- SSD Optimization:
  - Enables write-cache and power-protected cache flags where applicable.
  - Writes registry entries to disable SSD/SD idle power states and sets large idle timeouts.
  - Applies the same fsutil/NTFS tweaks as the HDD path.

3) Mouse and Keyboard Optimization
- CPU-profiled presets (Low / Medium / High) and a Revert option.
- Adjusts MouseDataQueueSize and KeyboardDataQueueSize.
- Disables selective suspend and other device power features for PCI/USB devices.
- Sets driver thread priorities for relevant drivers (e.g., usbxhci, USBHUB3, nvlddmkm, NDIS).
- Tweaks csrss.exe I/O and CPU priority hints, accessibility flags, and user mouse/keyboard speed preferences.
- Revert option attempts to restore defaults and remove applied registry keys.

4) RAM Optimization
- Quick presets (various MB options) and a Custom GB input mode (validated range).
- Updates SvcHostSplitThresholdInKB (controls services split behavior) and LargeSystemCache.
- For lower RAM sizes the script enables memory compression (MMAgent); for larger RAM sizes it disables memory compression and enables LargeSystemCache.
- Revert option restores default RAM-related registry values.

5) Startup Optimization
- Downloads and launches Sysinternals Autoruns (if not already present) and instructs the user to review the Logon tab and uncheck unwanted startup entries. Requires manual interaction and care to avoid disabling required Windows components.

6) Disable All Power Saving Features
- Options include:
  - All-in-One: disable hibernation, sleep timers, and device power saving.
  - Disable Hibernation only (powercfg -h off).
  - Disable Sleep only (set timeouts to 0).
  - Disable device selective suspend (affects USB/LAN/Wi‑Fi).
  - Revert: re-enable hibernation, restore reasonable timeouts and re-enable device power management.
- Changes may require reboot to fully take effect.

7) Exit
- Exits the script.

## How to Use

1. Download or clone this repository to a Windows machine.
2. Right-click TGO.bat and select "Run as administrator", or run it from an elevated Command Prompt. The script will attempt to relaunch elevated if needed.
3. Use the on-screen menu to select the optimization you want to apply.
4. Follow any on-screen instructions. Some tools (e.g., Autoruns) require manual interaction.

## Safety & Reverting

- The script includes revert flows for several areas (Mouse/Keyboard, RAM, Power settings) and provides a System Restore creation option.
- Despite revert options, some registry changes may persist or require a reboot. If unsure, create a system restore point or export registry keys before applying changes.

## Implementation Notes

- The script uses built-in Windows utilities (reg.exe, sc, net, fsutil, powercfg, cleanmgr, start, rstrui.exe) and PowerShell for specific tasks (file download and extraction, Clear-RecycleBin, Enable/Disable-MMAgent, Get-PnpDevice).
- Designed for Windows desktop/gaming environments; not recommended for servers or mission-critical systems without testing.

## Limitations

- Some operations depend on the presence of specific system files or PowerShell cmdlets and may fail silently (the script suppresses much output and redirects errors to minimize clutter).
- The script attempts to be cautious (offers reverts and restore point creation) but making changes to the registry and services always carries risk.

## License

No explicit license is included. Add a license file if you want to permit reuse.

## Support

If you want changes to the README text or want me to commit this file into the repository for you, tell me and I will proceed (or paste the contents above into a README.md in your repo).
