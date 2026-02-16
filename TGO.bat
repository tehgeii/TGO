@echo off
mode con: cols=100 lines=30

:: Check if running as administrator
fsutil dirty query %systemdrive% >nul
if %errorLevel% neq 0 (
    color 0C
    cls
    echo.
    echo [WARNING] Not running as administrator
    echo Some features may not work properly.
    echo Please run as Administrator for full functionality.
    echo.
    echo Restarting as Administrator...
    echo.
    
    :: This part will call UAC to "Run as administrator"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    
    :: Exit directly from the script (which does not have admin rights)
    exit
)

:: If the script gets here, it means it is ALREADY running as Administrator.
:: Hardware and OS Detection
:DETECT_HARDWARE
cls
echo Detecting Hardware info...

:: CPU Info
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"`) do set "CPU_MODEL=%%A"

:: OS Info
for /f "tokens=4-6 delims=. " %%i in ('ver') do set WIN_BUILD=%%k
if %WIN_BUILD% GEQ 22000 (
    set OS_NAME=Windows 11
    set GAME_MODE_VALUE=1
    set GAME_MODE_TARGET=ON
) else (
    set OS_NAME=Windows 10
    set GAME_MODE_VALUE=0
    set GAME_MODE_TARGET=OFF
)

:: GPU Info
:: Default Value
set "GPU_MODEL_DETAIL=Basic Display Adapter"
set "OPTIMIZE_GPU=UNKNOWN"

:: Check for NVIDIA
:: method 1: Check GPU name for NVIDIA keywords
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" | findstr /i "NVIDIA" >nul
if %errorlevel% equ 0 (
    set "OPTIMIZE_GPU=NVIDIA"
    for /f "usebackq tokens=*" %%N in (`powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -ExpandProperty Name | Select-Object -First 1"`) do set "GPU_MODEL_DETAIL=%%N"
    goto :HARDWARE_DONE
)
:: method 2: Check PNPDeviceID for NVIDIA vendor ID (VEN_10DE)
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "$gpus = Get-CimInstance Win32_VideoController; foreach($gpu in $gpus) { if($gpu.PNPDeviceID -match 'VEN_10DE') { $gpu.Name; break } }"') do (
    if not "%%A"=="" (
        set "OPTIMIZE_GPU=NVIDIA"
        set "GPU_MODEL_DETAIL=%%A"
        goto :HARDWARE_DONE
    )
)

:: Check for AMD
:: method 1: Check GPU name for AMD/ATI/Radeon keywords
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" | findstr /i "AMD Radeon ATI" >nul
if %errorlevel% equ 0 (
    set "OPTIMIZE_GPU=AMD"
    for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'AMD' -or $_.Name -match 'Radeon' -or $_.Name -match 'ATI' } | Select-Object -ExpandProperty Name | Select-Object -First 1"`) do set "GPU_MODEL_DETAIL=%%A"
    goto :HARDWARE_DONE
)
::method 2: Check PNPDeviceID for AMD vendor ID (VEN_1002)
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "$gpus = Get-CimInstance Win32_VideoController; foreach($gpu in $gpus) { if($gpu.PNPDeviceID -match 'VEN_1002') { $gpu.Name; break } }"') do (
    if not "%%A"=="" (
        set "OPTIMIZE_GPU=AMD"
        set "GPU_MODEL_DETAIL=%%A"
        goto :HARDWARE_DONE
    )
)

:: Check for INTEL
:: method 1: Check GPU name for Intel keywords
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name" | findstr /i "Intel" >nul
if %errorlevel% equ 0 (
    set "OPTIMIZE_GPU=INTEL"
    for /f "usebackq tokens=*" %%I in (`powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'Intel' } | Select-Object -ExpandProperty Name | Select-Object -First 1"`) do set "GPU_MODEL_DETAIL=%%I"
    goto :HARDWARE_DONE
)
:: method 2: Check PNPDeviceID for Intel vendor ID (VEN_8086)
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "$gpus = Get-CimInstance Win32_VideoController; foreach($gpu in $gpus) { if($gpu.PNPDeviceID -match 'VEN_8086') { $gpu.Name; break } }"') do (
    if not "%%A"=="" (
        set "OPTIMIZE_GPU=INTEL"
        set "GPU_MODEL_DETAIL=%%A"
        goto :HARDWARE_DONE
    )
)

:HARDWARE_DONE
:: Clean up CPU model string (remove extra spaces)
set "CPU_MODEL=%CPU_MODEL:  = %"

:: Determine CPU Type
echo "%CPU_MODEL%" | findstr /i "AMD" >nul && set CPU_TYPE=AMD
echo "%CPU_MODEL%" | findstr /i "Intel" >nul && set CPU_TYPE=INTEL

setlocal enabledelayedexpansion

:STARTUP_RESTORE_CHECK
cls
color 0E
echo.
echo ===================================
echo            SAFETY CHECK
echo ===================================
echo.
echo It is highly recommended to create a Restore Point
echo before applying any optimizations.
echo.
echo Would you like to create a System Restore Point now?
echo.
set /p start_rp="Select option (Y/N): "

if /i "%start_rp%"=="N" goto MAIN_MENU
if /i "%start_rp%"=="Y" goto STARTUP_CREATE_RP

echo Invalid choice
echo Press any key to continue...
pause >nul
goto STARTUP_RESTORE_CHECK

:STARTUP_CREATE_RP
cls
color 0E
echo.
echo Preparing to create Restore Point...
echo.
echo This may take a moment...
echo.

powershell -Command "Enable-ComputerRestore -Drive 'C:' -ErrorAction SilentlyContinue" >nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1

powershell -Command "Checkpoint-Computer -Description 'TGO Restore Point' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop" >nul

if %errorlevel% neq 0 (
    cls
    color 0C
    echo.
    echo [FAILED] Could not create restore point.
    echo System Restore might be disabled by Group Policy or disk is full.
    echo.
    echo Proceeding to Main Menu without Restore Point...
    timeout /t 3 >nul
) else (
    cls
    color 0A
    echo.
    echo [SUCCESS] Restore point created successfully!
    echo.
    echo Proceeding to Main Menu...
    timeout /t 3 >nul
)

reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

goto MAIN_MENU

:MAIN_MENU
cls
title TGO v1.5.5
color 0F
echo.
echo =========================================
echo       TGO - Tech Gameplay Optimizer
echo               Version 1.5.5
echo =========================================
echo.
echo [0] Restore Point
echo [1] Clean All Temporary Files
echo [2] Disk Optimization
echo [3] Mouse and Keyboard Optimization
echo [4] RAM Optimization
echo [5] Startup Optimization
echo [6] Disable All Power Saving Features
echo [7] CPU Optimization (Detected: %CPU_TYPE%)
echo [8] GPU Optimization (Detected: %OPTIMIZE_GPU%)
echo [9] Additional Tweaks
echo [C] Changelog
echo [E] Exit
echo.
set /p choice="Select option [0-9/C/E]: "

if "%choice%"=="0" goto SYSTEM_RESTORE_MENU
if "%choice%"=="1" goto CLEAN_TEMP
if "%choice%"=="2" goto DISK_OPTIMIZATION_MENU
if "%choice%"=="3" goto MOUSE_KEYBOARD_MENU
if "%choice%"=="4" goto RAM_OPTIMIZATION_MENU
if "%choice%"=="5" goto STARTUP_OPTIMIZATION
if "%choice%"=="6" goto POWER_SAVING
if "%choice%"=="7" goto CPU_MENU
if "%choice%"=="8" goto GPU_MENU
if "%choice%"=="9" goto ADDITIONAL_TWEAKS
if /i "%choice%"=="C" goto CHANGELOG
if /i "%choice%"=="E" exit

echo Invalid choice
echo Press any key to continue...
pause >nul
goto MAIN_MENU

:: ============================================================================
:: CLEAN TEMPORARY FILES
:: ============================================================================
:CLEAN_TEMP
cls
title Clean All Temporary Files
color 0E
echo.
echo ===============================
echo  Cleaning All Temporary Files
echo ===============================
echo.
echo This may take a few minutes.
echo Please wait...
echo.

:: Flush DNS cache
echo [0/8] Flushing DNS cache...
echo.
ipconfig /flushdns >nul 2>&1

:: Clean Windows temp files
echo [1/8] Cleaning Windows temp files...
echo.
del /s /f /q "%windir%\Temp\*.*" >nul 2>&1
del /s /f /q "%windir%\*.bak" >nul 2>&1

:: Clean user temp files
echo [2/8] Cleaning user temp files...
echo.
del /s /f /q "%temp%\*.*" >nul 2>&1
del /s /f /q "%systemdrive%\*.tmp" >nul 2>&1
del /s /f /q "%systemdrive%\*._mp" >nul 2>&1
del /s /f /q "%systemdrive%\*.log" >nul 2>&1
del /s /f /q "%systemdrive%\*.gid" >nul 2>&1
del /s /f /q "%systemdrive%\*.chk" >nul 2>&1
del /s /f /q "%systemdrive%\*.old" >nul 2>&1

:: Clean Windows logs
echo [3/8] Cleaning specific system logs...
echo.
del /f /q "%SystemRoot%\Logs\CBS\CBS.log" >nul 2>&1
del /f /q "%SystemRoot%\Logs\DISM\DISM.log" >nul 2>&1

:: Clean thumbnail cache
echo [4/8] Cleaning thumbnail cache...
echo.
del /s /f /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /s /f /q "%LocalAppData%\Microsoft\Windows\Explorer\*.db" >nul 2>&1
del /s /f /q "%LocalAppData%\D3DSCache\*.*" >nul 2>&1

:: Clean Windows Update cache
echo [5/8] Cleaning Windows Update cache...
echo.
net stop wuauserv >nul 2>&1
net stop UsoSvc >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1

rd /s /q "%windir%\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" >nul 2>&1
rd /s /q "%windir%\SoftwareDistribution" >nul 2>&1
md "%windir%\SoftwareDistribution" >nul 2>&1

:: Clean recycle bin
echo [6/8] Cleaning recycle bin...
echo.
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo [7/8] Starting disk cleanup...
echo.

:: Use /WAIT to wait for cleanmgr.exe to finish
start "" /WAIT cleanmgr.exe

:: Run disk optimization
echo [8/8] Running disk optimization...
powershell "Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue" >nul 2>&1

echo.
cls
color 0A
echo.
echo [SUCCESS] Temporary files cleanup completed
echo.
echo Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: DISK OPTIMIZATION
:: ============================================================================
:DISK_OPTIMIZATION_MENU
cls
title Disk Optimization
color 0F
echo.
echo =======================
echo    Disk Optimization
echo =======================
echo.
echo [1] HDD Optimization
echo [2] SSD Optimization
echo [3] Back to Main Menu
echo.
set /p disk_choice="Select disk type [1-3]: "

if "%disk_choice%"=="1" goto HDD_OPTIMIZATION
if "%disk_choice%"=="2" goto SSD_OPTIMIZATION
if "%disk_choice%"=="3" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto DISK_OPTIMIZATION_MENU

:HDD_OPTIMIZATION
cls
color 0E
echo.
echo Running HDD optimization.
echo Please wait...
echo.

echo (Step 1/3) Optimizing HDD Registry parameters...
echo.
For /f "Delims=" %%k in ('Reg.exe Query HKLM\SYSTEM\CurrentControlSet\Enum /f "{4d36e967-e325-11ce-bfc1-08002be10318}" /d /s^|Find "HKEY"') do (
    :: Disabling UserWriteCacheSetting
    Reg.exe delete "%%k\Device Parameters\Disk" /v UserWriteCacheSetting /f >nul 2>&1
    :: Enabling CacheIsPowerProtected
    Reg.exe add "%%k\Device Parameters\Disk" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f >nul 2>&1
)

echo (Step 2/3) Applying NTFS filesystem tweaks...
echo.
fsutil behavior set memoryusage 2 >nul 2>&1
fsutil behavior set disablelastaccess 1 >nul 2>&1
fsutil behavior set disabledeletenotify 0 >nul 2>&1
fsutil behavior set encryptpagingfile 0 >nul 2>&1
fsutil behavior set mftzone 4 >nul 2>&1
fsutil behavior set disable8dot3 1 >nul 2>&1

echo (Step 3/4) Disabling Prefetcher via Registry...
echo.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f >nul 2>&1

echo (Step 4/4) Disabling SysMain service...
echo.
:: Via Service
sc config SysMain start=disabled >nul 2>&1
sc stop SysMain >nul 2>&1
:: Via Registry
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul 2>&1

echo.
cls
color 0A
echo.
echo [SUCCESS] HDD optimization completed
echo.
echo Back to Disk Optimization menu...
timeout /t 3 >nul
goto DISK_OPTIMIZATION_MENU

:SSD_OPTIMIZATION
cls
color 0E
echo.
echo Running SSD optimization.
echo Please wait...
echo.

echo (Step 1/3) Optimizing SSD Registry parameters...
echo.
For /f "Delims=" %%k in ('Reg.exe Query HKLM\SYSTEM\CurrentControlSet\Enum /f "{4d36e967-e325-11ce-bfc1-08002be10318}" /d /s^|Find "HKEY"') do (
    :: Enabling UserWriteCacheSetting and CacheIsPowerProtected
    Reg.exe add "%%k\Device Parameters\Disk" /v UserWriteCacheSetting /t REG_DWORD /d 1 /f >nul 2>&1
    Reg.exe add "%%k\Device Parameters\Disk" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f >nul 2>&1
)

echo (Step 2/3) Disabling SSD Power Saving features...
echo.
:: Storage/SD
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1" /v "IdleExitEnergyMicroJoules" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1" /v "IdleExitLatencyMs" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1" /v "IdlePowerMw" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1" /v "IdleTimeLengthMs" /t REG_DWORD /d "4294967295" /f >nul 2>&1

:: Storage/SSD (IdleState 1, 2, & 3)
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1" /v "IdleExitEnergyMicroJoules" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1" /v "IdleExitLatencyMs" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1" /v "IdlePowerMw" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1" /v "IdleTimeLengthMs" /t REG_DWORD /d "4294967295" /f >nul 2>&1

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2" /v "IdleExitEnergyMicroJoules" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2" /v "IdleExitLatencyMs" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2" /v "IdlePowerMw" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\2" /v "IdleTimeLengthMs" /t REG_DWORD /d "4294967295" /f >nul 2>&1

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3" /v "IdleExitEnergyMicroJoules" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3" /v "IdleExitLatencyMs" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3" /v "IdlePowerMw" /t REG_DWORD /d "0" /f >nul 2>&1
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\3" /v "IdleTimeLengthMs" /t REG_DWORD /d "4294967295" /f >nul 2>&1

echo (Step 3/3) Applying NTFS filesystem tweaks...
echo.
fsutil behavior set memoryusage 2 >nul 2>&1
fsutil behavior set disablelastaccess 1 >nul 2>&1
fsutil behavior set disabledeletenotify 0 >nul 2>&1
fsutil behavior set encryptpagingfile 0 >nul 2>&1
fsutil behavior set disable8dot3 1 >nul 2>&1

echo.
cls
color 0A
echo.
echo [SUCCESS] SSD optimization completed
echo.
echo Back to Disk Optimization menu...
timeout /t 3 >nul
goto DISK_OPTIMIZATION_MENU

:: ============================================================================
:: MOUSE AND KEYBOARD OPTIMIZATION
:: ============================================================================
:MOUSE_KEYBOARD_MENU
cls
title Mouse and Keyboard Optimization
color 0F
echo.
echo ================================
echo Mouse and Keyboard Optimization
echo ================================
echo.
echo CPU Recommendations:
echo L - i3 or Ryzen 3 (Low)
echo M - i5 or Ryzen 5 (Medium)
echo H - i7, i9 or Ryzen 7, 9 (High)
echo R - Revert to Default
echo B - Back to Main Menu
echo.
set /p mk_choice="Select optimization level [L/M/H/R/B]: "

if /i "%mk_choice%"=="L" goto MK_LOW
if /i "%mk_choice%"=="M" goto MK_MEDIUM
if /i "%mk_choice%"=="H" goto MK_HIGH
if /i "%mk_choice%"=="R" goto MK_REVERT
if /i "%mk_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto MOUSE_KEYBOARD_MENU

:MK_LOW
cls
color 0E
echo.
echo Applying Low optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "34" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "34" /f >nul
goto MK_COMMON

:MK_MEDIUM
cls
color 0E
echo.
echo Applying Medium optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "24" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "24" /f >nul
goto MK_COMMON

:MK_HIGH
cls
color 0E
echo.
echo Applying High optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "19" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "19" /f >nul
goto MK_COMMON

:MK_COMMON
echo.
echo Applying advanced optimizations (Power, Priority, and Flags).
echo This may take a moment...

:: Turn off power saving features for PCI devices to keep latency low
for /f "delims=" %%i in ('powershell -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    set "pnpid=%%i"
    set "pnpid=!pnpid:\=\\!"
    set "regpath=HKLM\SYSTEM\CurrentControlSet\Enum\!pnpid!\Device Parameters"
    
    reg add "!regpath!" /v "AllowIdleIrpInD3" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "D3ColdSupported" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "DeviceSelectiveSuspended" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "EnableSelectiveSuspend" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "EnhancedPowerManagementEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "SelectiveSuspendEnabled" /t REG_DWORD /d "0" /f >nul 2>&1
    reg add "!regpath!" /v "SelectiveSuspendOn" /t REG_DWORD /d "0" /f >nul 2>&1
)

:: Driver Thread Priorities (Set to 31 - Realtime)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f >nul 2>&1

:: Optimizes IO and CPU priorities for input/graphics system processes
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "4" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f >nul 2>&1

:: Accessibility Flags & USB
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "0" /f >nul 2>&1

:: User Preference (Mouse & Keyboard Speed)
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f >nul
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f >nul
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f >nul
reg add "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f >nul
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d "0" /f >nul
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d "31" /f >nul

cls
color 0A
echo.
echo [SUCCESS] Optimization completed
echo.
echo Back to Mouse and Keyboard menu...
timeout /t 3 >nul
goto MOUSE_KEYBOARD_MENU

:MK_REVERT
cls
color 0E
echo.
echo Reverting to default settings.
echo Please wait...

:: Revert Queue Sizes
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "256" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "256" /f >nul

:: Revert CSRSS Priority
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "2" /f >nul 2>&1

:: Revert PCI Power Management (Deleting Keys)
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-PnpDevice -Class USB | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "AllowIdleIrpInD3" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "D3ColdSupported" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "DeviceSelectiveSuspended" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "EnableSelectiveSuspend" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "EnhancedPowerManagementEnabled" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "SelectiveSuspendEnabled" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "SelectiveSuspendOn" /f >nul 2>&1
)

:: Delete Thread Priorities
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /f >nul 2>&1

:: Revert USB Suspend
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "0" /f >nul 2>&1

:: Delete Accessibility Flags
reg delete "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /f >nul 2>&1
reg delete "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /f >nul 2>&1
reg delete "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /f >nul 2>&1
reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /f >nul 2>&1

cls
color 0A
echo.
echo [SUCCESS] Default settings restored
echo.
echo Back to Mouse and Keyboard menu...
timeout /t 3 >nul
goto MOUSE_KEYBOARD_MENU

:MK_DEFAULT
goto MK_REVERT

:: ============================================================================
:: RAM OPTIMIZATION
:: ============================================================================
:RAM_OPTIMIZATION_MENU
cls
title RAM Optimization
color 0F
echo.
echo =================
echo RAM Optimization
echo =================
echo.
echo Select input method:
echo.
echo [1] Quick Selection
echo [2] Custom Selection
echo.
echo [0] Revert to Default
echo [B] Back to Main Menu
echo.
set /p ram_choice="Options [1, 2, 0, B]: "

if "%ram_choice%"=="1" goto RAM_MANUAL_MENU
if "%ram_choice%"=="2" goto CUSTOM_RAM_GB
if "%ram_choice%"=="0" goto REVERT_RAM
if /i "%ram_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto RAM_OPTIMIZATION_MENU

:: Manual method (MB input)
:RAM_MANUAL_MENU
cls
color 0F
echo =========================
echo   RAM - Quick Selection
echo =========================
echo.
echo (Type "help" for more information, "revert" for default settings)
echo (Type "cancel" to cancel and go back)
echo.
set /p mb_choice=Enter your RAM Amount (in MB): 

if "%mb_choice%"=="2048" goto RAM_2048
if "%mb_choice%"=="3072" goto RAM_3072
if "%mb_choice%"=="4096" goto RAM_4096
if "%mb_choice%"=="6144" goto RAM_6144
if "%mb_choice%"=="8192" goto RAM_8192
if "%mb_choice%"=="10240" goto RAM_10240
if "%mb_choice%"=="12288" goto RAM_12288
if "%mb_choice%"=="16384" goto RAM_16384
if "%mb_choice%"=="20480" goto RAM_20480
if "%mb_choice%"=="24576" goto RAM_24576
if "%mb_choice%"=="32768" goto RAM_32768
if "%mb_choice%"=="49152" goto RAM_49152
if "%mb_choice%"=="65536" goto RAM_65536
if "%mb_choice%"=="131072" goto RAM_131072

if /i "%mb_choice%"=="revert" goto REVERT_RAM
if /i "%mb_choice%"=="help" goto RAM_MANUAL_HELP
if /i "%mb_choice%"=="cancel" goto RAM_OPTIMIZATION_MENU

:RAM_MANUAL_MISSPELL
cls
color 0C
echo.
echo [ERROR] Input not recognized.
echo "%mb_choice%" is not in the list.
echo.
echo Please go back and type "help" for more information.
pause
goto RAM_MANUAL_MENU

:RAM_MANUAL_HELP
cls
color 0F
echo =========================
echo      RAM Options List
echo =========================
echo If you are using 2GB of RAM, type 2048
echo If you are using 3GB of RAM, type 3072
echo If you are using 4GB of RAM, type 4096
echo If you are using 6GB of RAM, type 6144
echo If you are using 8GB of RAM, type 8192
echo If you are using 10GB of RAM, type 10240
echo If you are using 12GB of RAM, type 12288
echo If you are using 16GB of RAM, type 16384
echo If you are using 20GB of RAM, type 20480
echo If you are using 24GB of RAM, type 24576
echo If you are using 32GB of RAM, type 32768
echo If you are using 48GB of RAM, type 49152
echo If you are using 64GB of RAM, type 65536
echo If you are using 128GB of RAM, type 131072
echo.
echo if your RAM size is not listed, please use the Custom Selection method.
echo.
pause
goto RAM_MANUAL_MENU

:: RAM < 16GB
:RAM_2048
set "svc_value=2097152" & set "ram_desc=2048MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_3072
set "svc_value=3145728" & set "ram_desc=3072MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_4096
set "svc_value=4194304" & set "ram_desc=4096MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_6144
set "svc_value=6291456" & set "ram_desc=6144MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_8192
set "svc_value=8388608" & set "ram_desc=8192MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_10240
set "svc_value=10485760" & set "ram_desc=10240MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_12288
set "svc_value=12582912" & set "ram_desc=12288MB" & set "cache_val=0" & set "compress_cmd=Enable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL

:: RAM >= 16GB
:RAM_16384
set "svc_value=16777216" & set "ram_desc=16384MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_20480
set "svc_value=20971520" & set "ram_desc=20480MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_24576
set "svc_value=25165824" & set "ram_desc=24576MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_32768
set "svc_value=33554432" & set "ram_desc=32768MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_49152
set "svc_value=50331648" & set "ram_desc=49152MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_65536
set "svc_value=67108864" & set "ram_desc=65536MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL
:RAM_131072
set "svc_value=134217728" & set "ram_desc=131072MB" & set "cache_val=1" & set "compress_cmd=Disable-MMAgent -MemoryCompression"
goto APPLY_RAM_MANUAL

:APPLY_RAM_MANUAL
cls
color 0E
echo.
echo Applying settings for %ram_desc%...
echo Please wait...
reg add "HKLM\SYSTEM\ControlSet001\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d %svc_value% /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d %cache_val% /f >nul 2>&1
powershell "%compress_cmd% -ErrorAction SilentlyContinue" >nul 2>&1
goto RAM_SUCCESS

:: custom method (GB input)
:CUSTOM_RAM_GB
cls
color 0F
echo.
echo ==========================
echo   RAM - Custom Selection
echo ==========================
echo.
echo Supports from 2 GB up to 2047 GB
echo.
set "ram_size_gb="
set /p ram_size_gb="Enter your total RAM size (in GB): "

:: --- VALIDATION 1: EMPTY CHECK ---
if not defined ram_size_gb goto CUSTOM_RAM_GB

:: --- VALIDATION 2: CHECK PURE NUMBERS ---
echo %ram_size_gb%| findstr /r "^[0-9]*$" >nul
if %errorlevel% neq 0 (
    color 0C & echo. & echo [ERROR] Invalid input, Use NUMBERS only. & echo. & pause & color 0F & goto CUSTOM_RAM_GB
)
:: --- VALIDATION 3: CHECK MINIMUM VALUE ---
if %ram_size_gb% lss 2 (
    color 0C & echo. & echo [ERROR] Value too low, Minimum 2GB. & echo. & pause & color 0F & goto CUSTOM_RAM_GB
)
:: --- VALIDATION 4: CHECK MAXIMUM VALUE ---
if %ram_size_gb% gtr 2047 (
    color 0C & echo. & echo [ERROR] Value too high, Max 2047 GB. & echo. & pause & color 0F & goto CUSTOM_RAM_GB
)

cls
color 0E
echo.
echo Optimizing RAM for %ram_size_gb%GB...
echo.

:: Convert GB to KB
set /a svc_threshold_kb=%ram_size_gb% * 1024 * 1024

echo [1/3] Setting SvcHost Split Threshold...
echo.
reg add "HKLM\SYSTEM\ControlSet001\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d %svc_threshold_kb% /f >nul 2>&1

if %ram_size_gb% LEQ 15 (
    echo [2/3] Disabling Large System Cache...
    echo.
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 0 /f >nul 2>&1
    echo [3/3] Enabling Memory Compression...
    echo.
    powershell "Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue" >nul 2>&1
) else (
    echo [2/3] Enabling Large System Cache...
    echo.
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 1 /f >nul 2>&1
    echo [3/3] Disabling Memory Compression...
    echo.
    powershell "Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue" >nul 2>&1
)

set "ram_desc=%ram_size_gb%GB"
goto RAM_SUCCESS

:: default settings for ram
:REVERT_RAM
cls
color 0E
echo.
echo Reverting RAM settings to default...
echo Please wait...
reg add "HKLM\SYSTEM\ControlSet001\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d 380000 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 0 /f >nul 2>&1
powershell "Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue" >nul 2>&1

cls
color 0A
echo.
echo [SUCCESS] RAM settings reverted to default
echo.
echo Back to RAM Optimization menu...
timeout /t 3 >nul
goto RAM_OPTIMIZATION_MENU

:RAM_SUCCESS
cls
color 0A
echo.
echo [SUCCESS] RAM optimization completed for %ram_desc%
echo.
echo Back to RAM Optimization menu...
timeout /t 3 >nul
goto RAM_OPTIMIZATION_MENU

:: ============================================================================
:: STARTUP OPTIMIZATION
:: ============================================================================
:STARTUP_OPTIMIZATION
cls
title Startup Optimization
color 0E
echo.
echo ====================
echo Startup Optimization
echo ====================
echo.
echo Checking system architecture...

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo 64-bit system detected
    set autoruns_url=https://download.sysinternals.com/files/Autoruns.zip
    set autoruns_exe=Autoruns64.exe
) else (
    echo 32-bit system detected  
    set autoruns_url=https://download.sysinternals.com/files/Autoruns.zip
    set autoruns_exe=Autoruns.exe
)

:: Check first if the file already exists, no need to download it again and skip to the main part
set download_dir=C:\TGOResources\Autoruns
if not exist "%download_dir%\%autoruns_exe%" (
    echo.
    echo Downloading Autoruns...
    if not exist "%download_dir%" mkdir "%download_dir%"
    powershell -Command "Invoke-WebRequest -Uri '%autoruns_url%' -OutFile '%download_dir%\Autoruns.zip'" >nul 2>&1
    
    if exist "%download_dir%\Autoruns.zip" (
        echo Extracting Autoruns...
        powershell -Command "Expand-Archive -Path '%download_dir%\Autoruns.zip' -DestinationPath '%download_dir%' -Force" >nul 2>&1
        del "%download_dir%\Autoruns.zip" >nul 2>&1
    ) else (
        cls
        color 0C
        echo.
        echo [ERROR] Failed to download Autoruns
        echo Please check your internet connection.
        echo.
        echo Press any key to continue...
        pause >nul
        goto MAIN_MENU
    )
)

:: Main part
cls
color 0E
echo.
echo ==========================================
echo         Startup Optimization Guide
echo ==========================================
echo 1. Autoruns will open shortly...
echo 2. Go to the 'Logon' tab.
echo 3. Uncheck programs you want to disable from startup.
echo 4. BE CAREFUL: Do not disable Windows system files.
echo 5. CLOSE the Autoruns window to finish this step.
echo ===========================================
echo.
echo Launching Autoruns...
echo.
echo Waiting for user to close the Autoruns...

start /wait "" "%download_dir%\%autoruns_exe%"

cls
color 0A
echo.
echo [SUCCESS] Autoruns closed. Optimization finished.
echo.
echo Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: DISABLE POWER SAVING
:: ============================================================================
:POWER_SAVING
cls
title Disable All Power Saving Features
color 0F
echo.
echo ===============================
echo  Disable Power Saving Features
echo ===============================
echo.
echo [1] All-in-One
echo     - Disables Sleep Mode, Hibernation, and Power Saving modes all at once.
echo.
echo [2] Disable Hibernation
echo     - Saves SSD/HDD Space, improves performance by disabling Hibernation.
echo.
echo [3] Disable Sleep Mode
echo     - Prevent Windows from going to Sleep or turning off the screen.
echo.
echo [4] Disable All Power Saving on Devices
echo     - Prevent Windows from turning off USB/LAN/Wifi when idle.
echo.
echo [5] Revert to Default
echo [B] Back to Main Menu
echo.
set /p pwr_choice="Pilihan [1-5, B]: "

if "%pwr_choice%"=="1" goto PWR_DISABLE_ALL
if "%pwr_choice%"=="2" goto PWR_HIBERNATE
if "%pwr_choice%"=="3" goto PWR_SLEEP
if "%pwr_choice%"=="4" goto PWR_DEVICE
if "%pwr_choice%"=="5" goto PWR_REVERT
if /i "%pwr_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto POWER_SAVING

:: [1] ALL IN ONE
:PWR_DISABLE_ALL
cls
color 0E
echo.
echo [All-in-One] Disabling all power saving features...
echo.
echo 1. Disabling Hibernation...
echo.
powercfg -h off >nul 2>&1

echo 2. Disabling Sleep Mode...
echo.
powercfg -x -standby-timeout-ac 0 >nul 2>&1
powercfg -x -disk-timeout-ac 0 >nul 2>&1
powercfg -x -monitor-timeout-ac 0 >nul 2>&1

echo 3. Disabling All Power Saving on Devices...
echo.
powershell -Command "Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | ForEach-Object { $_.Enable = $false; $_.psbase.put() }" >nul 2>&1

goto PWR_SUCCESS

:: [2] HIBERNATE ONLY
:PWR_HIBERNATE
cls
color 0E
echo.
echo Disabling Hibernation...
powercfg -h off >nul 2>&1
goto PWR_SUCCESS

:: [3] SLEEP ONLY
:PWR_SLEEP
cls
color 0E
echo.
echo Disabling Sleep Mode...
powercfg -x -standby-timeout-ac 0 >nul 2>&1
powercfg -x -disk-timeout-ac 0 >nul 2>&1
powercfg -x -monitor-timeout-ac 0 >nul 2>&1
goto PWR_SUCCESS

:: [4] DEVICE MANAGEMENT ONLY
:PWR_DEVICE
cls
color 0E
echo.
echo Disabling Device Power Management (USB/LAN/Wifi)...
powershell -Command "Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | ForEach-Object { $_.Enable = $false; $_.psbase.put() }" >nul 2>&1
goto PWR_SUCCESS

:: [5] REVERT TO DEFAULT
:PWR_REVERT
cls
color 0E
echo.
echo Reverting Power Settings to Default...
echo.
echo 1. Enabling Hibernation...
echo.
powercfg -h on >nul 2>&1

echo 2. Setting Sleep Timer to 30 Minutes...
echo.
powercfg -x -standby-timeout-ac 30 >nul 2>&1
powercfg -x -disk-timeout-ac 20 >nul 2>&1
powercfg -x -monitor-timeout-ac 10 >nul 2>&1

echo 3. Enabling Device Power Management...
echo.
powershell -Command "Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | ForEach-Object { $_.Enable = $true; $_.psbase.put() }" >nul 2>&1

cls
color 0A
echo.
echo [SUCCESS] Power settings reverted to default
echo.
echo Back to Power Saving menu...
timeout /t 3 >nul
goto POWER_SAVING

:PWR_SUCCESS
cls
color 0A
echo.
echo [SUCCESS] Optimization Applied
echo.
echo Back to Power Saving menu...
timeout /t 3 >nul
goto POWER_SAVING

:: ============================================================================
:: SYSTEM RESTORE MENU
:: ============================================================================
:SYSTEM_RESTORE_MENU
cls
title System Restore Menu
color 0F
echo.
echo ====================
echo System Restore Menu
echo ====================
echo.
echo [1] Create Restore Point
echo [2] Open System Restore
echo [3] Back to Main Menu
echo.
set /p restore_choice="Select option [1-3]: "

if "%restore_choice%"=="1" goto CREATE_RESTORE
if "%restore_choice%"=="2" goto OPEN_RESTORE
if "%restore_choice%"=="3" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto SYSTEM_RESTORE_MENU

:CREATE_RESTORE
cls
color 0E
echo.
echo Creating system restore point...
echo This may take a moment, please wait...
echo.
    
:: This part ensures that System Restore is enabled on C: drive
powershell -Command "Enable-ComputerRestore -Drive 'C:' -ErrorAction SilentlyContinue" >nul 2>&1

:: Bypassing 24-hour cooldown rule
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1

:: -ErrorAction Stop: causing powershell to return errorlevel if failed
powershell -Command "Checkpoint-Computer -Description 'TGO Restore Point' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop" >nul

:: Check for errorlevel
if %errorlevel% neq 0 (
    :: if failed
    color 0C
    echo.
    echo [FAILED] Could not create restore point.
    echo.
    echo This is likely because:
    echo 1. The System Restore service is fully disabled.
    echo 2. Your C: drive is out of disk space.
        
    :: Keep the cooldown rule removed even if failed
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
        
    echo.
    pause
    goto SYSTEM_RESTORE_MENU
)

:: IF SUCCESSFUL, remove the cooldown rule
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

echo.
cls
color 0A
echo.
echo [SUCCESS] Restore point created successfully
echo.
echo Back to System Restore menu...
timeout /t 3 >nul
goto SYSTEM_RESTORE_MENU

:OPEN_RESTORE
echo.
echo Opening System Restore...

:: First check where rstrui.exe is located
set "RSTRUI_PATH="
if exist "%SystemRoot%\System32\rstrui.exe" set "RSTRUI_PATH=%SystemRoot%\System32\rstrui.exe"
if exist "%SystemRoot%\SysNative\rstrui.exe" set "RSTRUI_PATH=%SystemRoot%\SysNative\rstrui.exe"

:: Check first: IF NOT FOUND, jump directly to :RESTORE_NOT_FOUND
if not defined RSTRUI_PATH goto :RESTORE_NOT_FOUND

:: IF FOUND (script will continue here if 'if not defined' above FAILED)
cls
color 0E
echo.
echo ===========================================
echo   WAITING FOR SYSTEM RESTORE TO CLOSED...
echo ===========================================
echo.
echo Launching System Restore...

:: This /WAIT command will "lock" the script
start "" /WAIT "%RSTRUI_PATH%"

:: After the user closes rstrui.exe, the script will continue here
color 0A
cls
echo.
echo [SUCCESS] System Restore has closed.
echo.
echo Back to System Restore menu...
timeout /t 3 >nul
goto SYSTEM_RESTORE_MENU

:RESTORE_NOT_FOUND
cls
color 0C
echo.
echo System Restore (rstrui.exe) not found.
echo Opening System Protection settings instead...
start "" systempropertiesprotection
echo.
echo ===========================================
echo Instructions:
echo 1. Open 'System Protection' menu.
echo 2. Click 'System Restore...' button.
echo ===========================================
echo.
pause
goto SYSTEM_RESTORE_MENU

:: ============================================================================
:: CPU OPTIMIZATION
:: ============================================================================
:CPU_MENU
cls
title CPU Optimization
color 0F
echo ==============================================
echo                CPU OPTIMIZATION
echo Detected: %CPU_MODEL%
echo ==============================================
echo.
echo [1] Applying TGP (Ultimate Performance)
echo [2] Applying TGE (Energy Saving Mode)
if "%CPU_TYPE%"=="AMD" echo [3] AMD CPU Boost Optimization
echo [R] Revert All CPU Settings to Default
echo [B] Back to Main Menu
echo.
set /p cpu_choice="Select option [1-3/R/B]: "

if "%cpu_choice%"=="1" goto SMART_POWER_PLAN
if "%cpu_choice%"=="2" goto ENERGY_SAVING_PLAN
if "%cpu_choice%"=="3" if "%CPU_TYPE%"=="AMD" goto CPU_AMD_BOOST
if /i "%cpu_choice%"=="R" goto CPU_REVERT
if /i "%cpu_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto CPU_MENU

:DOWNLOAD_RESOURCES
cls
color 0E
echo.
echo Downloading the power plan...
echo.
curl -L -o "%temp%\TGOResources.zip" "https://github.com/tehgeii/TGOResources/archive/refs/heads/main.zip"

if not exist "%temp%\TGOResources.zip" (
    color 0C
    echo [FAILED] Could not download the power plan. Check your internet connection.
    pause
    goto CPU_MENU
)

echo.
echo Extracting...
rmdir /s /q "%temp%\TGOResources_Extract" >nul 2>&1
powershell -command "Expand-Archive -Path '%temp%\TGOResources.zip' -DestinationPath '%temp%\TGOResources_Extract' -Force"
echo.
if not exist "C:\TGOResources" mkdir "C:\TGOResources"
xcopy /E /I /Y "%temp%\TGOResources_Extract\TGOResources-main\*" "C:\TGOResources\" >nul 2>&1

echo.
echo [SUCCESS] Power plan downloaded and extracted.
exit /b

:: ==============================================================
:: TGP (TECH GAMEPLAY PERFORMANCE)
:: ==============================================================
:SMART_POWER_PLAN
call :DOWNLOAD_RESOURCES
cls
color 0E
echo.
echo Importing TGP...
echo.

:: check if file exists
if not exist "C:\TGOResources\TGP.pow" (
    color 0C
    echo [FAILED] TGP.pow not found in C:\TGOResources\
    echo Please ensure the download was successful.
    pause
    goto CPU_MENU
)

powercfg -import "C:\TGOResources\TGP.pow" 00000000-0000-0000-0000-000000000000 >nul 2>&1
powercfg -setactive 00000000-0000-0000-0000-000000000000 >nul 2>&1

:: check if activated
powercfg /getactivescheme | find "00000000-0000-0000-0000-000000000000" >nul
if %errorlevel%==0 (
    cls
    color 0A
    echo.
    echo =============================================
    echo [SUCCESS] TGP ULTIMATE PERFORMANCE ACTIVATED!
    echo =============================================
    echo.
    echo Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
) else (
    cls
    color 0C
    echo [WARNING] Failed to activate TGP. Trying default High Performance...
    powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    echo [SUCCESS] High Performance Activated.
    echo Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
)

echo Back to CPU Optimization menu...
timeout /t 3 >nul
goto CPU_MENU

:: ==============================================================
:: TGE (TECH GAMEPLAY ENERGY SAVING)
:: ==============================================================
:ENERGY_SAVING_PLAN
call :DOWNLOAD_RESOURCES
cls
color 0E
echo.
echo Importing TGE...
echo.

:: check if file exists
if not exist "C:\TGOResources\TGE.pow" (
    color 0C
    echo [FAILED] TGE.pow not found in C:\TGOResources\
    echo Please ensure the download was successful.
    pause
    goto CPU_MENU
)

powercfg -import "C:\TGOResources\TGE.pow" 11111111-1111-1111-1111-111111111111 >nul 2>&1
powercfg -setactive 11111111-1111-1111-1111-111111111111 >nul 2>&1

:: check if activated
powercfg /getactivescheme | find "11111111-1111-1111-1111-111111111111" >nul
if %errorlevel%==0 (
    cls
    color 0A
    echo.
    echo =====================================
    echo [SUCCESS] TGE ENERGY SAVER ACTIVATED!
    echo =====================================
    echo.
    echo Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
) else (
    cls
    color 0C
    echo [WARNING] Failed to activate TGE.
    echo Reverting to default power schemes...
    powercfg -restoredefaultschemes
    echo Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
)

echo Back to CPU Optimization menu...
timeout /t 3 >nul
goto CPU_MENU

:CPU_AMD_BOOST
cls
color 0E
echo.
echo Applying AMD CPU Boost Optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Throttle" /v "PerfEnablePackageIdle" /t REG_DWORD /d 0 /f >nul 2>&1
cls
color 0A
echo [SUCCESS] AMD CPU Boost Applied.
echo.
echo Back to CPU menu...
timeout /t 3 >nul
goto CPU_MENU

:CPU_REVERT
cls
color 0E
powercfg -restoredefaultschemes
if "%CPU_TYPE%"=="AMD" reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Throttle" /f >nul 2>&1
cls
color 0A
echo [SUCCESS] CPU Settings Reverted.
echo.
echo Back to CPU menu...
timeout /t 3 >nul
goto CPU_MENU

:: ============================================================================
:: GPU OPTIMIZATION
:: ============================================================================
:GPU_MENU
cls
title GPU Optimization
color 0F
echo ==============================================
echo                GPU OPTIMIZATION
echo Detected GPUs: %GPU_MODEL_DETAIL%
echo ==============================================
echo.
echo [1] Enable HAGS (Hardware Accelerated GPU Scheduling)
echo [2] Optimize Game Mode (%OS_NAME%)
if "%OPTIMIZE_GPU%"=="NVIDIA" echo [N] NVIDIA GPU Tweaks
if "%OPTIMIZE_GPU%"=="AMD" echo [A] AMD GPU Tweaks
if "%OPTIMIZE_GPU%"=="INTEL" echo [I] INTEL GPU Tweaks
if "%OPTIMIZE_GPU%"=="NVIDIA" echo [R] Revert NVIDIA GPU Settings to Default
if "%OPTIMIZE_GPU%"=="AMD" echo [R] Revert AMD GPU Settings to Default
if "%OPTIMIZE_GPU%"=="INTEL" echo [R] Revert INTEL GPU Settings to Default
echo [B] Back to Main Menu
echo.
set /p gpu_choice="Select option [1-2/N/A/I/R/B]: "

if "%gpu_choice%"=="1" goto GPU_HAGS_ON
if "%gpu_choice%"=="2" goto GPU_GAMEMODE
if /i "%gpu_choice%"=="N" if "%OPTIMIZE_GPU%"=="NVIDIA" goto GPU_NVIDIA_TWEAK
if /i "%gpu_choice%"=="A" if "%OPTIMIZE_GPU%"=="AMD" goto GPU_AMD_TWEAK
if /i "%gpu_choice%"=="I" if "%OPTIMIZE_GPU%"=="INTEL" goto GPU_INTEL_TWEAK
if /i "%gpu_choice%"=="R" goto GPU_REVERT
if /i "%gpu_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto GPU_MENU

:GPU_HAGS_ON
cls
color 0E
echo Enabling HAGS...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f >nul 2>&1
cls
color 0A
echo [SUCCESS] HAGS Enabled. Restart Required
echo.
echo Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:GPU_GAMEMODE
echo.
echo Optimizing Game Mode For (%OS_NAME%)...
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d %GAME_MODE_VALUE% /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d %GAME_MODE_VALUE% /f >nul 2>&1
cls
color 0A
echo [SUCCESS] Game Mode Set to %GAME_MODE_TARGET%
echo.
echo Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:GPU_NVIDIA_TWEAK
cls
echo.
echo Searching for NVIDIA GPU Registry Keys...
set FOUND_NVIDIA=0
for /f "tokens=*" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /v "DriverDesc" ^| findstr /i "NVIDIA"') do (
    set "KEY_PATH=%%k"
    for /f "delims=" %%p in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /f "NVIDIA" ^| find "HKEY"') do (
        echo Applying tweaks to: %%p
        set FOUND_NVIDIA=1
        reg add "%%p" /v "DisableDynamicPstate" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%p" /v "RMHdcpKeyglobZero" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%p" /v "PreferSystemMemoryContiguous" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%p" /v "D3PCLatency" /t REG_DWORD /d 1 /f >nul 2>&1
    )
)

if "%FOUND_NVIDIA%"=="0" (
    echo [INFO] No NVIDIA GPU keys found in registry.
) else (
    echo.
    echo Apply Global NVIDIA Power Tweaks...
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "QosManagesIdleProcessors" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "HighPerformance" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v "DisplayPowerSaving" /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatencyCheckEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceDefault" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceFSVP" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyTolerancePerfOverride" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceScreenOffIR" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceVSyncEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "RtlCapabilityCheckLatency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleShortTime" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleVeryLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceMemory" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContextMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceOther" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceTimerPeriod" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceActivelyUsed" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MiracastPerfTrackGraphicsLatency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorRefreshLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "TransitionLatency" /t REG_DWORD /d "1" /f >nul 2>&1
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "NvBackend" /f >nul 2>&1
    echo [SUCCESS] NVIDIA GPU Optimization Applied.
)
pause
goto GPU_MENU

:GPU_AMD_TWEAK
cls
echo.
echo Searching for AMD GPU Registry Keys...
set FOUND_AMD=0
for /f "tokens=*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /v "DriverDesc" ^| findstr /i "AMD ATI Radeon"') do (
   rem This finds the line with DriverDesc. We need the Key above it.
   rem Better approach: Iterate keys, check value.
)

for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /k /f "0"') do (
    reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "AMD ATI Radeon" >nul
    if !errorlevel! equ 0 (
        echo Applying AMD Tweaks to: %%k
        set FOUND_AMD=1
        reg add "%%k" /v "AsicOnLowPower" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "EnableUlps" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "PP_GPUPowerDownEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "PP_SclkDeepSleepDisable" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "PP_ThermalAutoThrottlingEnable" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "KMD_EnableContextBasedPowerManagement" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "StutterMode" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "KMD_DeLagEnabled" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "DisableBlockWrite" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "DisabledMACopy" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "KMD_FRTEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "AutoColorDepthReduction_NA" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "AllowSkins" /t REG_SZ /d "false" /f >nul 2>&1
        reg add "%%k" /v "Adaptive De-interlacing" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "AreaAniso_NA" /t REG_SZ /d "0" /f >nul 2>&1
        reg add "%%k" /v "AllowSubscription" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k\UMD" /v "Main3D_DEF" /t REG_SZ /d "1" /f >nul 2>&1
        reg add "%%k\UMD" /v "Main3D" /t REG_BINARY /d "3100" /f >nul 2>&1
        reg add "%%k\UMD" /v "FlipQueueSize" /t REG_BINARY /d "3100" /f >nul 2>&1
        reg add "%%k\UMD" /v "ShaderCache" /t REG_BINARY /d "3200" /f >nul 2>&1
        reg add "%%k\UMD" /v "TFQ" /t REG_BINARY /d "3200" /f >nul 2>&1

        for /f "delims=" %%h in ('reg query "%%k" /s /f "Option" ^| findstr /i "DAL2_DATA.*DisplayPath.*Option"') do (
            reg add "%%h" /v "ProtectionControl" /t REG_BINARY /d "0100000001000000" /f >nul 2>&1
        )
    )
)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\amdlog" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatencyCheckEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceDefault" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceFSVP" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyTolerancePerfOverride" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceScreenOffIR" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceVSyncEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "RtlCapabilityCheckLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleShortTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleVeryLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceMemory" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContextMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceOther" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceTimerPeriod" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceActivelyUsed" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MiracastPerfTrackGraphicsLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorRefreshLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "TransitionLatency" /t REG_DWORD /d "1" /f >nul 2>&1

if "%FOUND_AMD%"=="0" echo [INFO] No AMD GPU keys found.
if "%FOUND_AMD%"=="1" echo [SUCCESS] AMD GPU Optimization Applied.
pause
goto GPU_MENU

:GPU_INTEL_TWEAK
cls
echo.
echo Searching for INTEL GPU Registry Keys...
set FOUND_INTEL=0
for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /k /f "0"') do (
    reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "Intel" >nul
    if !errorlevel! equ 0 (
        echo Applying INTEL Tweaks to: %%k
        set FOUND_INTEL=1
        reg add "%%k" /v "Disable_OverlayDSQualityEnhancement" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "IncreaseFixedSegment" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "AdaptiveVbEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "DisablePFonDP" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "EnableCompensationForDVI" /t REG_DWORD /d 1 /f >nul 2>&1
        reg add "%%k" /v "NoFastLinkTrainingForeDP" /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "%%k" /v "ACPowerPolicyVersion" /t REG_DWORD /d 16898 /f >nul 2>&1
        reg add "%%k" /v "DCPowerPolicyVersion" /t REG_DWORD /d 16642 /f >nul 2>&1
    )
)
reg add "HKLM\SOFTWARE\Intel\GMM" /v "DedicatedSegmentSize" /t REG_DWORD /d 512 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" /v "Start" /t REG_DWORD /d "4" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatencyCheckEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceDefault" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceFSVP" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyTolerancePerfOverride" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceScreenOffIR" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceVSyncEnabled" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "RtlCapabilityCheckLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleShortTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultD3TransitionLatencyIdleVeryLongTime" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle0MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceIdle1MonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceMemory" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceNoContextMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceOther" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultLatencyToleranceTimerPeriod" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceActivelyUsed" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceMonitorOff" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "DefaultMemoryRefreshLatencyToleranceNoContext" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MiracastPerfTrackGraphicsLatency" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "MonitorRefreshLatencyTolerance" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "TransitionLatency" /t REG_DWORD /d "1" /f >nul 2>&1

if "%FOUND_INTEL%"=="0" echo [INFO] No Intel GPU keys found.
if "%FOUND_INTEL%"=="1" echo [SUCCESS] Intel GPU Optimization Applied.
pause
goto GPU_MENU

:GPU_REVERT
echo.
cls
color 0E
echo Detected GPUs: %GPU_MODEL_DETAIL%
timeout /t 2 >nul
echo Reverting %OPTIMIZE_GPU% GPU Tweaks...
rem Revert HAGS
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 1 /f >nul 2>&1
rem Revert Game Mode (Delete keys or set to 0)
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
if "%OPTIMIZE_GPU%"=="NVIDIA" (
    echo Reverting NVIDIA Tweaks...
    for /f "tokens=*" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /v "DriverDesc" ^| findstr /i "NVIDIA"') do (
        set "KEY_PATH=%%k"
        for /f "delims=" %%p in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /f "NVIDIA" ^| find "HKEY"') do (
            echo Reverting tweaks on: %%p
            reg delete "%%p" /v "DisableDynamicPstate" /f >nul 2>&1
            reg delete "%%p" /v "RMHdcpKeyglobZero" /f >nul 2>&1
            reg delete "%%p" /v "PreferSystemMemoryContiguous" /f >nul 2>&1
            reg delete "%%p" /v "D3PCLatency" /f >nul 2>&1
        )
    )
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "QosManagesIdleProcessors" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "HighPerformance" /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" /v "DisplayPowerSaving" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" /v "Start" /t REG_DWORD /d "2" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" /v "Start" /t REG_DWORD /d "2" /f >nul 2>&1
)
if "%OPTIMIZE_GPU%"=="AMD" (
    echo Reverting AMD Tweaks...
    for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /k /f "0"') do (
        reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "AMD ATI Radeon" >nul
        if !errorlevel! equ 0 (
            echo Reverting tweaks on: %%k
            reg delete "%%k" /v "AsicOnLowPower" /f >nul 2>&1
            reg delete "%%k" /v "EnableUlps" /f >nul 2>&1
            reg delete "%%k" /v "PP_GPUPowerDownEnabled" /f >nul 2>&1
            reg delete "%%k" /v "PP_SclkDeepSleepDisable" /f >nul 2>&1
            reg delete "%%k" /v "PP_ThermalAutoThrottlingEnable" /f >nul 2>&1
            reg delete "%%k" /v "KMD_EnableContextBasedPowerManagement" /f >nul 2>&1
            reg delete "%%k" /v "StutterMode" /f >nul 2>&1
            reg delete "%%k" /v "KMD_DeLagEnabled" /f >nul 2>&1
            reg delete "%%k" /v "DisableBlockWrite" /f >nul 2>&1
            reg delete "%%k" /v "DisabledMACopy" /f >nul 2>&1
            reg delete "%%k" /v "KMD_FRTEnabled" /f >nul 2>&1
            reg delete "%%k" /v "AutoColorDepthReduction_NA" /f >nul 2>&1
            reg delete "%%k" /v "AllowSkins" /f >nul 2>&1
            reg delete "%%k" /v "Adaptive De-interlacing" /f >nul 2>&1
            reg delete "%%k" /v "AreaAniso_NA" /f >nul 2>&1
            reg delete "%%k" /v "AllowSubscription" /f >nul 2>&1
            reg delete "%%k\UMD" /v "Main3D_DEF" /f >nul 2>&1
            reg delete "%%k\UMD" /v "Main3D" /f >nul 2>&1
            reg delete "%%k\UMD" /v "FlipQueueSize" /f >nul 2>&1
            reg delete "%%k\UMD" /v "ShaderCache" /f >nul 2>&1
            reg delete "%%k\UMD" /v "TFQ" /f >nul 2>&1

            for /f "delims=" %%h in ('reg query "%%k" /s /f "Option" ^| findstr /i "DAL2_DATA.*DisplayPath.*Option"') do (
                reg delete "%%h" /v "ProtectionControl" /f >nul 2>&1
            )
        )
    )
)
if "%OPTIMIZE_GPU%"=="INTEL" (
    echo Reverting Intel Tweaks...
    for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /k /f "0"') do (
        reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "Intel" >nul
        if !errorlevel! equ 0 (
            echo Reverting tweaks on: %%k
            reg delete "%%k" /v "Disable_OverlayDSQualityEnhancement" /f >nul 2>&1
            reg delete "%%k" /v "IncreaseFixedSegment" /f >nul 2>&1
            reg delete "%%k" /v "AdaptiveVbEnabled" /f >nul 2>&1
            reg delete "%%k" /v "DisablePFonDP" /f >nul 2>&1
            reg delete "%%k" /v "EnableCompensationForDVI" /f >nul 2>&1
            reg delete "%%k" /v "NoFastLinkTrainingForeDP" /f >nul 2>&1
            reg delete "%%k" /v "ACPowerPolicyVersion" /f >nul 2>&1
            reg delete "%%k" /v "DCPowerPolicyVersion" /f >nul 2>&1
        )
    )
    reg delete "HKLM\SOFTWARE\Intel\GMM" /v "DedicatedSegmentSize" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" /v "Start" /t REG_DWORD /d "2" /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" /v "Start" /t REG_DWORD /d "2" /f >nul 2>&1
)
cls
color 0A
echo [SUCCESS] GPU Settings Reverted.
echo.
echo Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:: ============================================================================
:: CHANGELOG
:: ============================================================================
:CHANGELOG
cls
title Changelog
color 0F
echo =========================================
echo           TGO CHANGELOG
echo =========================================
echo.
echo [v1.5.5]
echo  + Added Additional Tweaks Menu.
echo  + Updated GPU Optimization with more tweaks.
echo  + Updated Clean All Temporary Files.
echo  + Fixed Hardware Detection for some models.
echo  + And more...
echo.
echo [v1.4.0]
echo  + Added Hardware Detection (OS, CPU, GPU)
echo  + Added CPU Optimization Menu.
echo  + Added GPU Optimization Menu.
echo.
echo [v1.0.1]
echo + Added a startup safety check.
echo + Minor fixes and stability improvements.
echo.
echo [v1.0.0]
echo + Initial Release of Tech Gameplay Optimizer (TGO)
echo.
pause
goto MAIN_MENU

:: ============================================================================
:: ADDITIONAL TWEAKS
:: ============================================================================
:ADDITIONAL_TWEAKS
call :DOWNLOAD_RESOURCESS
cls
title Additional Tweaks
color 0F
echo.
echo =====================================
echo           ADDITIONAL TWEAKS
echo =====================================
echo.
echo [1] Turn on or off Windows Update
echo [2] Turn on or off Windows Security (Permanently)
echo [3] Turn off all Windows Animations
echo [4] Delete all useless apps via third-party tool
echo [5] Turn on or off User Account Control
echo [B] Back to Main Menu
echo.
set /p add_choice="Select option [1-5/B]: "

if "%add_choice%"=="1" goto WINDOWS_UPDATE
if "%add_choice%"=="2" goto WINDOWS_SECURITY
if "%add_choice%"=="3" goto ADVANCED_SYSTEM_SETTINGS
if "%add_choice%"=="4" goto DELETE_APPS
if "%add_choice%"=="5" goto UAC
if /i "%add_choice%"=="B" goto MAIN_MENU

echo Invalid choice
echo Press any key to continue...
pause >nul
goto ADDITIONAL_TWEAKS

:ADVANCED_SYSTEM_SETTINGS
cls
color 0E
echo.
echo ==============================================
echo Follow this step to disable all the animations
echo ==============================================
echo 1. Performance Options window will be open shortly...
echo 2. Choose 'Adjust for best performance'.
echo 3. Check the box 'Show thumbnails instead of icons', 'Smooth edges of screen fonts',
echo    and 'Show window contents while dragging'.
echo 4. After that, click 'Apply' and then 'OK' to save the settings.
echo 5. CLOSE the Performance Options window to finish this step.
echo ==============================================
echo.

start /wait "" %windir%\System32\SystemPropertiesPerformance.exe

cls
color 0A
echo.
echo [SUCCESS] Performance Options window closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:DOWNLOAD_RESOURCESS
cls
color 0E
echo.
echo Downloading all the materials...
echo.

if exist "C:\TGOResources\" (
    exit /b
)

curl -L -o "%temp%\TGOResources.zip" "https://github.com/tehgeii/TGOResources/archive/refs/heads/main.zip"

if %errorlevel% neq 0 (
    color 0C
    echo [FAILED] Could not download all the materials.
    echo Please check your internet connection.
    pause
    goto ADDITIONAL_TWEAKS
)

if exist "%temp%\TGOResources_Extract" rmdir /s /q "%temp%\TGOResources_Extract" >nul 2>&1

powershell -command "Expand-Archive -Path '%temp%\TGOResources.zip' -DestinationPath '%temp%\TGOResources_Extract' -Force"

if not exist "C:\TGOResources" mkdir "C:\TGOResources"

xcopy /E /I /Y "%temp%\TGOResources_Extract\TGOResources-main\*" "C:\TGOResources\" >nul 2>&1

del /f /q "%temp%\TGOResources.zip" >nul 2>&1
rmdir /s /q "%temp%\TGOResources_Extract" >nul 2>&1

echo.
echo [SUCCESS] All the Additional Tweaks materials downloaded and extracted.
exit /b

:WINDOWS_UPDATE
cls
color 0E
echo.
echo ============================================
echo         Windows Update Blocker Guide
echo ============================================
echo 1. Choose 'Disable Updates' (with the option checked) to turn off Windows Update.
echo 2. Choose 'Enable Updates' to turn on Windows Update.
echo 3. Then hit 'Apply Now' button to save the settings.
echo 4. CLOSE the WUB window to finish this step.
echo ============================================
echo.
:: check if file exists
if not exist "C:\TGOResources\Wub_x64.exe" (
    color 0C
    echo [FAILED] Wub_x64.exe not found in C:\TGOResources\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGOResources\Wub_x64.exe"

cls
color 0A
echo.
echo [SUCCESS] Windows Update Blocker closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:WINDOWS_SECURITY
cls
color 0E
echo.
echo Waiting for all the processes related to Windows Security to be completed...
echo.

if not exist "C:\TGOResources\Disable Windows Security Permanent\PowerRun.exe" (
    color 0C
    echo [FAILED] PowerRun.exe not found in C:\TGOResources\Disable Windows Security Permanent\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

:: Set Path variabel
set "BASE_PATH=C:\TGOResources\Disable Windows Security Permanent"
set "PWR_EXE=%BASE_PATH%\PowerRun.exe"
set "OFF_BAT=%BASE_PATH%\off.bat"
set "OFF_REG=%BASE_PATH%\off.reg"

powershell -Command "Start-Process -FilePath '%PWR_EXE%' -ArgumentList '\"%OFF_BAT%\"' -Wait"
powershell -Command "Start-Process -FilePath '%PWR_EXE%' -ArgumentList 'regedit.exe', '/s', '\"%OFF_REG%\"' -Wait"

cls
color 0A
echo.
echo [SUCCESS] Windows Security has been turned off permanently. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:DELETE_APPS
cls
color 0E
echo.
echo ===========================================
echo              Delete Apps Guide
echo ===========================================
echo 1. geek will be launched shortly...
echo 2. Inside geek, select the apps you want to delete.
echo 3. After selecting, right click on the selected apps and choose 'Uninstall'.
echo 4. After the uninstallation is done, CLOSE geek to finish this step.
echo ===========================================
echo.
:: check if file exists
if not exist "C:\TGOResources\geek.exe" (
    color 0C
    echo [FAILED] geek not found in C:\TGOResources\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGOResources\geek.exe"

cls
color 0A
echo.
echo [SUCCESS] geek has been closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UAC
cls
color 0F
echo.
echo Do you want to turn on or off User Account Control (UAC)?
echo.
echo [1] Turn ON UAC
echo [2] Turn OFF UAC
echo.
set /p uac_choice="Select option [1-2]: "

if "%uac_choice%"=="1" goto UAC_ON
if "%uac_choice%"=="2" goto UAC_OFF

echo Invalid choice
echo Press any key to continue...
pause >nul
goto UAC
echo.

:UAC_OFF
if not exist "C:\TGOResources\UAC Off\off.bat" (
    color 0C
    echo [FAILED] off.bat not found in C:\TGOResources\UAC Off\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGOResources\UAC Off\off.bat"

cls
color 0A
echo.
echo [SUCCESS] UAC has been turned off. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UAC_ON
if not exist "C:\TGOResources\UAC On\on.bat" (
    color 0C
    echo [FAILED] on.bat not found in C:\TGOResources\UAC On\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)
start /wait "" "C:\TGOResources\UAC On\on.bat"

:UACF
cls
color 0F
echo.
echo Do you want to remove the black screen when turning on UAC?
echo.
echo [1] Yes
echo [2] No
echo.
set /p uacf_choice="Select option [1-2]: "

if "%uacf_choice%"=="1" goto UACF_ON
if "%uacf_choice%"=="2" goto UACF_OFF

echo Invalid choice
echo Press any key to continue...
pause >nul
goto UACF

:UACF_ON
if not exist "C:\TGOResources\UAC On\on without black screen.bat" (
    color 0C
    echo [FAILED] on without black screen.bat not found in C:\TGOResources\UAC On\
    echo Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)
start /wait "" "C:\TGOResources\UAC On\on without black screen.bat"

cls
color 0A
echo.
echo [SUCCESS] UAC has been turned on. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UACF_OFF
cls
color 0A
echo.
echo [SUCCESS] UAC has been turned on. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:: ============================================================================
:: END OF SCRIPT
:: ============================================================================
