@echo off
chcp 65001 >nul
mode con: cols=100 lines=100

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
echo     Detecting Hardware info...

:: CPU Info
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"`) do set "CPU_MODEL=%%A"
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors"') do set "CPU_THREADS=%%a"
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

:: RAM Detection
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)"') do set RAM_GB=%%A
if not defined RAM_GB set RAM_GB=8
if %RAM_GB% lss 4 set RAM_GB=4
if %RAM_GB% gtr 128 set RAM_GB=128

:: Storage Type Detection
set "STORAGE_TYPE=UNKNOWN"

:: Method 1: MediaType from Get-PhysicalDisk (most accurate)
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "try { $disk = Get-Partition -DriveLetter C | Get-Disk; $phys = $disk | Get-PhysicalDisk -ErrorAction Stop; $phys.MediaType } catch { '' }" 2^>nul') do set "STORAGE_TYPE=%%A"

:: Method 2: BusType + RotationalSpeed ​​(fallback if MediaType is empty)
if "%STORAGE_TYPE%"=="" (
    for /f "tokens=*" %%A in ('powershell -NoProfile -Command "try { $disk = Get-Partition -DriveLetter C | Get-Disk; $bus = $disk.BusType; $rot = $disk.RotationalSpeed; if ($bus -eq 'NVMe' -or ($bus -eq 'SATA' -and $rot -eq 0)) { 'SSD' } elseif ($rot -gt 0) { 'HDD' } else { '' } } catch { '' }" 2^>nul') do set "STORAGE_TYPE=%%A"
)

:: Method 3: Keyword in FriendlyName (backup if both methods above fail)
if "%STORAGE_TYPE%"=="" (
    for /f "tokens=*" %%A in ('powershell -NoProfile -Command "try { $disk = Get-Partition -DriveLetter C | Get-Disk; $model = $disk.FriendlyName; if ($model -match 'SSD|NVMe|Solid|M\\.2') { 'SSD' } else { 'HDD' } } catch { '' }" 2^>nul') do set "STORAGE_TYPE=%%A"
)

:: Method 4: If all else fails, leave it UNKNOWN (user will be guided manually in the menu)
if "%STORAGE_TYPE%"=="" set "STORAGE_TYPE=UNKNOWN"

setlocal enabledelayedexpansion

:RESOURCES
cls
if not exist "C:\TGO\Disable Windows Security Permanent\off.bat"      goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\Disable Windows Security Permanent\off.reg"      goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\Disable Windows Security Permanent\PowerRun.exe" goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\UAC Off\off.bat"                                 goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\UAC On\on without black screen.bat"              goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\UAC On\on.bat"                                   goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\geek.exe"                                        goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\TGP.pow"                                         goto DOWNLOAD_RESOURCES
if not exist "C:\TGO\Wub_x64.exe"                                     goto DOWNLOAD_RESOURCES

goto STARTUP_RESTORE_CHECK

:STARTUP_RESTORE_CHECK
cls
color 0E
echo.
echo     ───────────────────────────────────
echo                 SAFETY CHECK
echo     ───────────────────────────────────
echo.
echo     It is highly recommended to create a Restore Point
echo     before applying any optimizations.
echo.
echo     Would you like to create a System Restore Point now?
echo.
set /p start_rp="Select option (Y/N): "

if /i "%start_rp%"=="N" goto MAIN_MENU
if /i "%start_rp%"=="Y" goto STARTUP_CREATE_RP

echo Invalid selection
echo Press any key to continue...
pause >nul
goto STARTUP_RESTORE_CHECK

:STARTUP_CREATE_RP
cls
color 0E
echo.
echo     Preparing to create Restore Point...
echo.
echo     This may take a moment...
echo.

powershell -Command "Enable-ComputerRestore -Drive 'C:' -ErrorAction SilentlyContinue" >nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f >nul 2>&1

powershell -Command "Checkpoint-Computer -Description 'TGO Restore Point' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop" >nul

if %errorlevel% neq 0 (
    cls
    call :WRITE_LOG "Safety check failed to created"
    color 0C
    echo.
    echo     [FAILED] Could not create restore point.
    echo     System Restore might be disabled by Group Policy or disk is full.
    echo.
    echo     Proceeding to Main Menu without Restore Point...
    timeout /t 3 >nul
) else (
    cls
    call :WRITE_LOG "Safety check successfully created"
    color 0A
    echo.
    echo     [SUCCESS] Restore point created successfully!
    echo.
    echo     Proceeding to Main Menu...
    timeout /t 3 >nul
)

reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

goto MAIN_MENU

:PRINT_HEADER
cls
color 0B
echo.
echo                     ████████╗ ██████╗  ██████╗ 
echo                     ╚══██╔══╝██╔════╝ ██╔═══██╗
echo                        ██║   ██║  ███╗██║   ██║
echo                        ██║   ██║   ██║██║   ██║
echo                        ██║   ╚██████╔╝╚██████╔╝
echo                        ╚═╝    ╚═════╝  ╚═════╝ 
echo.
color 0F
echo                    Tech Gameplay Optimizer  v2.1.0
echo     ──────────────────────────────────────────────────────────────
echo     •  OS: %OS_NAME%
echo     •  CPU: %CPU_MODEL%
echo     •  GPU: %GPU_MODEL_DETAIL%
echo     •  RAM: %RAM_GB%GB
echo     •  DISK TYPE: %STORAGE_TYPE%
echo     ──────────────────────────────────────────────────────────────
echo.
goto :eof

:MAIN_MENU
call :PRINT_HEADER
title TGO v2.1.0
color 0F
echo     MAIN MENU
echo.
echo     [1]  Clean All Temporary Files
echo     [2]  Disk Optimization                 (Detected: %STORAGE_TYPE%)
echo     [3]  Mouse and Keyboard Optimization   (Detected: %CPU_THREADS% CPU Threads)
echo     [4]  RAM Optimization                  (Detected: %RAM_GB%GB)
echo     [5]  Startup Programs Manager
echo     [6]  Disable Power Saving Features
echo     [7]  CPU Optimization                  (Detected: %CPU_TYPE%)
echo     [8]  GPU Optimization                  (Detected: %OPTIMIZE_GPU%)
echo     [9]  Services Optimization
echo.
echo     [0]  System Restore and Recovery
echo     [A]  Additional Tools and Tweaks
echo.
echo     [R]  Redownload All Resources
echo     [L]  View Optimization Log
echo     [C]  Changelog
echo     [E]  Exit
echo.
set /p choice="Select option: "

if "%choice%"=="1" goto CLEAN_TEMP
if "%choice%"=="2" goto DISK_OPTIMIZATION_MENU
if "%choice%"=="3" goto MOUSE_KEYBOARD_MENU
if "%choice%"=="4" goto RAM_OPTIMIZATION_MENU
if "%choice%"=="5" goto STARTUP_OPTIMIZATION
if "%choice%"=="6" goto POWER_SAVING
if "%choice%"=="7" goto CPU_MENU
if "%choice%"=="8" goto GPU_MENU
if "%choice%"=="9" goto SERVICES_OPTIMIZATION_MENU
if "%choice%"=="0" goto SYSTEM_RESTORE_MENU
if /i "%choice%"=="A" goto ADDITIONAL_TWEAKS
if /i "%choice%"=="R" goto REDOWNLOAD
if /i "%choice%"=="L" goto VIEW_LOG
if /i "%choice%"=="C" goto CHANGELOG
if /i "%choice%"=="E" exit

echo Invalid selection
echo Press any key to continue...
pause >nul
goto MAIN_MENU

:: ============================================================================
:: VIEW LOG
:: ============================================================================
:VIEW_LOG
if not exist "C:\TGO\logs" mkdir "C:\TGO\logs" >nul 2>&1
if not exist "C:\TGO\logs\TGO_Log.txt" (
    echo No log file found yet. Run optimizations first.
    echo Press any key to continue...
    pause >nul
    goto MAIN_MENU
)
start "" notepad "C:\TGO\logs\TGO_Log.txt"
goto MAIN_MENU

:: ============================================================================
:: CLEAN TEMPORARY FILES
:: ============================================================================
:CLEAN_TEMP
title Clean All Temporary Files
call :PRINT_HEADER
color 0E
echo     CLEAN ALL TEMPORARY FILES
echo.
echo     This may take a few minutes.
echo     Please wait...
echo.

:: Flush DNS cache
echo     [0/8] Flushing DNS cache...
echo.
ipconfig /flushdns >nul 2>&1

:: Clean Windows temp files
echo     [1/8] Cleaning Windows temp files...
echo.
del /s /f /q "%windir%\Temp\*.*" >nul 2>&1
del /s /f /q "%windir%\*.bak" >nul 2>&1

:: Clean user temp files
echo     [2/8] Cleaning user temp files...
echo.
del /s /f /q "%temp%\*.*" >nul 2>&1
del /s /f /q "%systemdrive%\*.tmp" >nul 2>&1
del /s /f /q "%systemdrive%\*._mp" >nul 2>&1
del /s /f /q "%systemdrive%\*.log" >nul 2>&1
del /s /f /q "%systemdrive%\*.gid" >nul 2>&1
del /s /f /q "%systemdrive%\*.chk" >nul 2>&1
del /s /f /q "%systemdrive%\*.old" >nul 2>&1

:: Clean Windows logs
echo     [3/8] Cleaning specific system logs...
echo.
del /f /q "%SystemRoot%\Logs\CBS\CBS.log" >nul 2>&1
del /f /q "%SystemRoot%\Logs\DISM\DISM.log" >nul 2>&1

:: Clean thumbnail cache
echo     [4/8] Cleaning thumbnail cache...
echo.
del /s /f /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /s /f /q "%LocalAppData%\Microsoft\Windows\Explorer\*.db" >nul 2>&1
del /s /f /q "%LocalAppData%\D3DSCache\*.*" >nul 2>&1

:: Clean Windows Update cache
echo     [5/8] Cleaning Windows Update cache...
echo.
net stop wuauserv >nul 2>&1
net stop UsoSvc >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1

rd /s /q "%windir%\ServiceProfiles\LocalService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" >nul 2>&1
rd /s /q "%windir%\SoftwareDistribution" >nul 2>&1
md "%windir%\SoftwareDistribution" >nul 2>&1

:: Clean recycle bin
echo     [6/8] Cleaning recycle bin...
echo.
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo     [7/8] Starting disk cleanup...
echo.

:: Use /WAIT to wait for cleanmgr.exe to finish
start "" /WAIT cleanmgr.exe

:: Run disk optimization
echo     [8/8] Running disk optimization...
powershell "Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue" >nul 2>&1

call :WRITE_LOG "Temporary files cleaned (DNS flush, temp, logs, thumbcache, update cache, recycle bin, disk cleanup, optimize C drive)"
echo.
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Temporary files cleanup completed
echo.
echo     Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: DISK OPTIMIZATION
:: ============================================================================
:DISK_OPTIMIZATION_MENU
title Disk Optimization
call :PRINT_HEADER
color 0F
echo     DISK OPTIMIZATION
echo.
echo     Detected Storage Type: %STORAGE_TYPE%
echo.
timeout /t 2 >nul

if /i "%STORAGE_TYPE%"=="SSD" (
    echo     SSD detected. Running automatic SSD optimization...
    timeout /t 3 >nul
    goto SSD_OPTIMIZATION
) else if /i "%STORAGE_TYPE%"=="HDD" (
    echo     HDD detected. Running automatic HDD optimization...
    timeout /t 3 >nul
    goto HDD_OPTIMIZATION
) else (
    echo     Could not auto-detect storage type.
    echo.
    echo     [1] HDD Optimization
    echo     [2] SSD Optimization
    echo     [B] Back to Main Menu
    echo.
    set /p disk_choice="Select option: "
    if "%disk_choice%"=="1" goto HDD_OPTIMIZATION
    if "%disk_choice%"=="2" goto SSD_OPTIMIZATION
    if /i "%disk_choice%"=="B" goto MAIN_MENU
    echo Invalid selection
    echo Press any key to continue...
    pause >nul
    goto DISK_OPTIMIZATION_MENU
)

:HDD_OPTIMIZATION
call :PRINT_HEADER
color 0E
echo     Please wait...
echo.

echo     (Step 1/3) Optimizing HDD Registry parameters...
echo.
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PnpDevice -Class DiskDrive -PresentOnly | ForEach-Object { $_.InstanceId }"') do (
    for /f "delims=" %%a in ("%%i") do set "diskid=%%a"
    set "diskpath=HKLM\SYSTEM\CurrentControlSet\Enum\!diskid!\Device Parameters\Disk"
    
    reg delete "!diskpath!" /v "UserWriteCacheSetting" /f >nul 2>&1
    reg add "!diskpath!" /v "CacheIsPowerProtected" /t REG_DWORD /d "1" /f >nul 2>&1
)

echo     (Step 2/3) Applying NTFS filesystem tweaks...
echo.
fsutil behavior set memoryusage 2 >nul 2>&1
fsutil behavior set disablelastaccess 1 >nul 2>&1
fsutil behavior set disabledeletenotify 0 >nul 2>&1
fsutil behavior set encryptpagingfile 0 >nul 2>&1
fsutil behavior set mftzone 4 >nul 2>&1
fsutil behavior set disable8dot3 1 >nul 2>&1

echo     (Step 3/4) Disabling Prefetcher via Registry...
echo.
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f >nul 2>&1

echo     (Step 4/4) Disabling SysMain service...
echo.
:: Via Service
sc config SysMain start=disabled >nul 2>&1
sc stop SysMain >nul 2>&1
:: Via Registry
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul 2>&1

call :WRITE_LOG "HDD optimization applied (registry, NTFS tweaks, prefetcher disabled, SysMain disabled)"
echo.
call :PRINT_HEADER
color 0A
echo     [SUCCESS] HDD optimization completed
echo.
echo     Back to Main Menu...
timeout /t 5 >nul
goto MAIN_MENU

:SSD_OPTIMIZATION
call :PRINT_HEADER
color 0E
echo     Please wait...
echo.

echo     (Step 1/3) Optimizing SSD Registry parameters...
echo.
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PnpDevice -Class DiskDrive -PresentOnly | ForEach-Object { $_.InstanceId }"') do (
    for /f "delims=" %%a in ("%%i") do set "diskid=%%a"
    set "diskpath=HKLM\SYSTEM\CurrentControlSet\Enum\!diskid!\Device Parameters\Disk"
    
    :: Eksekusi pembuatan folder Disk dan pengisian tweaks Cache
    reg add "!diskpath!" /v "UserWriteCacheSetting" /t REG_DWORD /d "1" /f >nul 2>&1
    reg add "!diskpath!" /v "CacheIsPowerProtected" /t REG_DWORD /d "1" /f >nul 2>&1
)

echo     (Step 2/3) Disabling SSD Power Saving features...
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

echo     (Step 3/3) Applying NTFS filesystem tweaks...
echo.
fsutil behavior set memoryusage 2 >nul 2>&1
fsutil behavior set disablelastaccess 1 >nul 2>&1
fsutil behavior set disabledeletenotify 0 >nul 2>&1
fsutil behavior set encryptpagingfile 0 >nul 2>&1
fsutil behavior set disable8dot3 1 >nul 2>&1

call :WRITE_LOG "SSD optimization applied (registry write cache enabled, power saving disabled, NTFS tweaks)"
echo.
call :PRINT_HEADER
color 0A
echo     [SUCCESS] SSD optimization completed
echo.
echo     Back to Main Menu...
timeout /t 5 >nul
goto MAIN_MENU

:: ============================================================================
:: MOUSE AND KEYBOARD OPTIMIZATION
:: ============================================================================
:MOUSE_KEYBOARD_MENU
title Mouse and Keyboard Optimization
call :PRINT_HEADER
color 0F
echo     MOUSE AND KEYBOARD OPTIMIZATION
echo.
echo     Detected Logical Processors: %CPU_THREADS% Threads
echo.
timeout /t 3 >nul

if %CPU_THREADS% GEQ 2 if %CPU_THREADS% LEQ 4 (
    echo     Low-tier CPU detected. Running Low optimization...
    timeout /t 5 >nul
    goto MK_LOW
)
if %CPU_THREADS% GEQ 6 if %CPU_THREADS% LEQ 12 (
    echo     Medium-tier CPU detected. Running Medium optimization...
    timeout /t 5 >nul
    goto MK_MEDIUM
)
if %CPU_THREADS% GEQ 16 if %CPU_THREADS% LEQ 32 (
    echo     High-tier CPU detected. Running High optimization...
    timeout /t 5 >nul
    goto MK_HIGH
)

:: ============================================================================
:: MANUAL INPUT FOR ANOMALIES OR UNKNOWN CPU
:: ============================================================================
echo     [WARNING] CPU anomaly or unknown thread count detected.
echo     Please select the optimization level manually:
echo.
echo     L - i3 / Ryzen 3 / Celeron / Athlon (Low)
echo     M - i5 / Ryzen 5 (Medium)
echo     H - i7 / i9 / Ryzen 7 / Ryzen 9 (High)
echo     R - Revert to Default
echo     B - Back to Main Menu
echo.
set /p mk_choice="Select optimization level: "

if /i "%mk_choice%"=="L" goto MK_LOW
if /i "%mk_choice%"=="M" goto MK_MEDIUM
if /i "%mk_choice%"=="H" goto MK_HIGH
if /i "%mk_choice%"=="R" goto MK_REVERT
if /i "%mk_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto MOUSE_KEYBOARD_MENU

:MK_LOW
call :PRINT_HEADER
color 0E
echo.
echo     Applying Low optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "34" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "34" /f >nul
set MK_LEVEL=Low
goto MK_COMMON

:MK_MEDIUM
call :PRINT_HEADER
color 0E
echo.
echo     Applying Medium optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "24" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "24" /f >nul
set MK_LEVEL=Medium
goto MK_COMMON

:MK_HIGH
call :PRINT_HEADER
color 0E
echo.
echo     Applying High optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "19" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "19" /f >nul
set MK_LEVEL=High
goto MK_COMMON

:MK_COMMON
echo.
echo     Applying advanced optimizations (Power, Priority, and Flags)
echo     This may take a moment...

:: Turn off power saving features for PCI devices to keep latency low
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like \"PCI\VEN_*\" } | ForEach-Object { $_.InstanceId }"') do (
    for /f "delims=" %%a in ("%%i") do set "pnpid=%%a"
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

call :WRITE_LOG "Mouse & Keyboard optimization (%MK_LEVEL%) applied"
echo.
call :PRINT_HEADER
color 0A
echo     [SUCCESS] %MK_LEVEL% Optimization completed
echo.
echo     [0] Revert to Default Settings
echo     [B] Back to Main Menu
echo.
set /p mousek_choice="Select option: "

if "%mousek_choice%"=="0" goto MK_REVERT
if /i "%mousek_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto MAIN_MENU

:MK_REVERT
call :PRINT_HEADER
color 0E
echo.
echo     Reverting to default settings.
echo     Please wait...

:: Revert Queue Sizes
reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "256" /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "256" /f >nul

:: Revert CSRSS Priority
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "2" /f >nul 2>&1

:: Revert PCI Power Management (Deleting Keys)
for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like \"PCI\VEN_*\" } | ForEach-Object { $_.InstanceId }"') do (
    for /f "delims=" %%a in ("%%i") do set "pnpid=%%a"
    set "regpath=HKLM\SYSTEM\CurrentControlSet\Enum\!pnpid!\Device Parameters"
    
    reg delete "!regpath!" /v "AllowIdleIrpInD3" /f >nul 2>&1
    reg delete "!regpath!" /v "D3ColdSupported" /f >nul 2>&1
    reg delete "!regpath!" /v "DeviceSelectiveSuspended" /f >nul 2>&1
    reg delete "!regpath!" /v "EnableSelectiveSuspend" /f >nul 2>&1
    reg delete "!regpath!" /v "EnhancedPowerManagementEnabled" /f >nul 2>&1
    reg delete "!regpath!" /v "SelectiveSuspendEnabled" /f >nul 2>&1
    reg delete "!regpath!" /v "SelectiveSuspendOn" /f >nul 2>&1
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

call :WRITE_LOG "Mouse & Keyboard optimization default settings restored"
echo.
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Default Mouse and Keyboard settings restored
echo.
echo     Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: RAM OPTIMIZATION
:: ============================================================================
:RAM_OPTIMIZATION_MENU
title RAM Optimization
call :PRINT_HEADER
color 0F
echo     RAM OPTIMIZATION
echo.
echo     Detected RAM: %RAM_GB% GB
echo.

if %RAM_GB% LEQ 15 (
    echo     Applying optimized settings...
    set /A "svc_value=%RAM_GB%*1024*1024"
    set "ram_desc=%RAM_GB%GB"
    set "cache_val=0"
    set "compress_cmd=Enable-MMAgent -MemoryCompression"
) else (
    echo     Applying high-performance settings...
    set /A "svc_value=%RAM_GB%*1024*1024"
    set "ram_desc=%RAM_GB%GB"
    set "cache_val=1"
    set "compress_cmd=Disable-MMAgent -MemoryCompression"
)

echo.
echo     Applying settings for %ram_desc%...
echo     Please wait...
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d %svc_value% /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d %cache_val% /f >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "%compress_cmd% -ErrorAction SilentlyContinue" >nul 2>&1

call :WRITE_LOG "RAM optimization applied for %RAM_GB%GB (SvcHostSplitThreshold=%svc_value%, LargeSystemCache=%cache_val%, memory compression toggled)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] RAM optimization completed for %ram_desc%
echo.
echo     [0] Revert to Default Settings
echo     [B] Back to Main Menu
echo.
set /p ram_choice="Select option: "

if "%ram_choice%"=="0" goto REVERT_RAM
if /i "%ram_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto MAIN_MENU

:: ============================================================================
:: DEFAULT RAM SETTINGS
:: ============================================================================
:REVERT_RAM
call :PRINT_HEADER
color 0E
echo     Reverting RAM settings to default...
echo     Please wait...
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d 3670016 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "LargeSystemCache" /t REG_DWORD /d 0 /f >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue" >nul 2>&1

call :WRITE_LOG "RAM optimization default settings applied"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] RAM settings reverted to default
echo     Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: STARTUP OPTIMIZATION
:: ============================================================================
:STARTUP_OPTIMIZATION
call :PRINT_HEADER
title Startup Optimization
color 0E
echo     STARTUP OPTIMIZATION
echo.
echo     Checking system architecture...

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo     64-bit system detected
    set autoruns_url=https://download.sysinternals.com/files/Autoruns.zip
    set autoruns_exe=Autoruns64.exe
) else (
    echo     32-bit system detected  
    set autoruns_url=https://download.sysinternals.com/files/Autoruns.zip
    set autoruns_exe=Autoruns.exe
)

:: Check first if the file already exists, no need to download it again and skip to the main part
set download_dir=C:\TGO\Autoruns
if not exist "%download_dir%\%autoruns_exe%" (
    echo.
    echo     Downloading Autoruns...
    if not exist "%download_dir%" mkdir "%download_dir%"
    powershell -Command "Invoke-WebRequest -Uri '%autoruns_url%' -OutFile '%download_dir%\Autoruns.zip'" >nul 2>&1
    
    if exist "%download_dir%\Autoruns.zip" (
        echo     Extracting Autoruns...
        powershell -Command "Expand-Archive -Path '%download_dir%\Autoruns.zip' -DestinationPath '%download_dir%' -Force" >nul 2>&1
        del "%download_dir%\Autoruns.zip" >nul 2>&1
    ) else (
        call :WRITE_LOG "Failed to download Autoruns"
        call :PRINT_HEADER
        color 0C
        echo     [ERROR] Failed to download Autoruns
        echo     Please check your internet connection.
        echo.
        echo     Press any key to continue...
        pause >nul
        goto MAIN_MENU
    )
)

:: Main part
call :PRINT_HEADER
color 0E
echo     Startup Optimization Guide
echo.
echo     1. Autoruns will open shortly...
echo     2. Go to the 'Logon' tab.
echo     3. Uncheck programs you want to disable from startup.
echo     4. BE CAREFUL: Do not disable Windows system files.
echo     5. CLOSE the Autoruns window to finish this step.
echo.
echo     Launching Autoruns...
echo.
echo     Waiting for user to close the Autoruns...

start /wait "" "%download_dir%\%autoruns_exe%"

call :WRITE_LOG "Startup programs managed via Autoruns (user manually unchecked items)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Autoruns closed. Optimization finished.
echo.
echo     Back to Main Menu...
timeout /t 3 >nul
goto MAIN_MENU

:: ============================================================================
:: DISABLE POWER SAVING
:: ============================================================================
:POWER_SAVING
call :PRINT_HEADER
title Disable All Power Saving Features
color 0F
echo     DISABLE POWER SAVING FEATURES
echo.
echo     [1] All-in-One
echo     - Disables Sleep Mode, Hibernation, and Power Saving modes all at once.
echo.
echo     [2] Disable Hibernation
echo     - Saves SSD/HDD Space, improves performance by disabling Hibernation.
echo.
echo     [3] Disable Sleep Mode
echo     - Prevent Windows from going to Sleep or turning off the screen.
echo.
echo     [4] Disable All Power Saving on Devices
echo     - Prevent Windows from turning off USB/LAN/Wifi when idle.
echo.
echo     [5] Revert to Default
echo     [B] Back to Main Menu
echo.
set /p pwr_choice="Select option: "

if "%pwr_choice%"=="1" goto PWR_DISABLE_ALL
if "%pwr_choice%"=="2" goto PWR_HIBERNATE
if "%pwr_choice%"=="3" goto PWR_SLEEP
if "%pwr_choice%"=="4" goto PWR_DEVICE
if "%pwr_choice%"=="5" goto PWR_REVERT
if /i "%pwr_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto POWER_SAVING

:: [1] ALL IN ONE
:PWR_DISABLE_ALL
call :PRINT_HEADER
color 0E
echo     [All-in-One] Disabling all power saving features...
echo.
echo     1. Disabling Hibernation...
echo.
powercfg -h off >nul 2>&1

echo     2. Disabling Sleep Mode...
echo.
powercfg -x -standby-timeout-ac 0 >nul 2>&1
powercfg -x -disk-timeout-ac 0 >nul 2>&1
powercfg -x -monitor-timeout-ac 0 >nul 2>&1

echo     3. Disabling All Power Saving on Devices...
echo.
powershell -Command "Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | ForEach-Object { $_.Enable = $false; $_.psbase.put() }" >nul 2>&1
call :WRITE_LOG "All power saving features disabled"
goto PWR_SUCCESS

:: [2] HIBERNATE ONLY
:PWR_HIBERNATE
call :PRINT_HEADER
color 0E
echo     Disabling Hibernation...
powercfg -h off >nul 2>&1
call :WRITE_LOG "Hibernation disabled"
goto PWR_SUCCESS

:: [3] SLEEP ONLY
:PWR_SLEEP
call :PRINT_HEADER
color 0E
echo     Disabling Sleep Mode...
powercfg -x -standby-timeout-ac 0 >nul 2>&1
powercfg -x -disk-timeout-ac 0 >nul 2>&1
powercfg -x -monitor-timeout-ac 0 >nul 2>&1
call :WRITE_LOG "Sleep mode disabled"
goto PWR_SUCCESS

:: [4] DEVICE MANAGEMENT ONLY
:PWR_DEVICE
call :PRINT_HEADER
color 0E
echo     Disabling Device Power Management (USB/LAN/Wifi)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable | ForEach-Object { $_.Enable = $false; Set-CimInstance -CimInstance $_ }" >nul 2>&1
call :WRITE_LOG "Device power management disabled (USB, LAN, WiFi idle power off)"
goto PWR_SUCCESS

:: [5] REVERT TO DEFAULT
:PWR_REVERT
call :PRINT_HEADER
color 0E
echo     Reverting Power Settings to Default...
echo.
echo     1. Enabling Hibernation...
echo.
powercfg -h on >nul 2>&1

echo     2. Setting Sleep Timer to 30 Minutes...
echo.
powercfg -x -standby-timeout-ac 30 >nul 2>&1
powercfg -x -disk-timeout-ac 20 >nul 2>&1
powercfg -x -monitor-timeout-ac 10 >nul 2>&1

echo     3. Enabling Device Power Management...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable | ForEach-Object { $_.Enable = $true; Set-CimInstance -CimInstance $_ }" >nul 2>&1

call :WRITE_LOG "All power settings reverted to default (hibernation on, sleep timers restored, device power management enabled)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Power settings reverted to default
echo.
echo     Back to Power Saving menu...
timeout /t 3 >nul
goto POWER_SAVING

:PWR_SUCCESS
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Power settings optimization Applied
echo.
echo     Back to Power Saving menu...
timeout /t 3 >nul
goto POWER_SAVING

:: ============================================================================
:: SYSTEM RESTORE MENU
:: ============================================================================
:SYSTEM_RESTORE_MENU
title System Restore Menu
call :PRINT_HEADER
color 0F
echo     SYSTEM RESTORE MENU
echo.
echo     [1] Create Restore Point
echo     [2] Open System Restore
echo     [B] Back to Main Menu
echo.
set /p restore_choice="Select option: "

if "%restore_choice%"=="1" goto CREATE_RESTORE
if "%restore_choice%"=="2" goto OPEN_RESTORE
if /i "%restore_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto SYSTEM_RESTORE_MENU

:CREATE_RESTORE
title Create System Restore Point
call :PRINT_HEADER
color 0E
echo.
echo     Creating system restore point...
echo     This may take a moment, please wait...
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
    call :WRITE_LOG "Failed to create restore point"
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] Could not create restore point.
    echo.
    echo     This is likely because:
    echo     1. The System Restore service is fully disabled.
    echo     2. Your C: drive is out of disk space.
        
    :: Keep the cooldown rule removed even if failed
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1
        
    echo.
    pause
    goto SYSTEM_RESTORE_MENU
)

:: IF SUCCESSFUL, remove the cooldown rule
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /f >nul 2>&1

call :WRITE_LOG "Successfully creating restore point"
echo.
call :PRINT_HEADER
color 0A
echo.
echo     [SUCCESS] Restore point created successfully
echo.
echo     Back to System Restore menu...
timeout /t 3 >nul
goto SYSTEM_RESTORE_MENU

:OPEN_RESTORE
title Open System Restore
call :PRINT_HEADER
color 0F
echo.
echo     Opening System Restore...

:: First check where rstrui.exe is located
set "RSTRUI_PATH="
if exist "%SystemRoot%\System32\rstrui.exe" set "RSTRUI_PATH=%SystemRoot%\System32\rstrui.exe"
if exist "%SystemRoot%\SysNative\rstrui.exe" set "RSTRUI_PATH=%SystemRoot%\SysNative\rstrui.exe"

:: Check first: IF NOT FOUND, jump directly to :RESTORE_NOT_FOUND
if not defined RSTRUI_PATH goto :RESTORE_NOT_FOUND

:: IF FOUND (script will continue here if 'if not defined' above FAILED)
call :PRINT_HEADER
color 0E
echo.
echo     ───────────────────────────────────────────
echo       WAITING FOR SYSTEM RESTORE TO CLOSED...
echo     ───────────────────────────────────────────
echo.
echo     Launching System Restore...

:: This /WAIT command will "lock" the script
start "" /WAIT "%RSTRUI_PATH%"

:: After the user closes rstrui.exe, the script will continue here
color 0A
call :PRINT_HEADER
echo.
echo     [SUCCESS] System Restore has closed.
echo.
echo     Back to System Restore menu...
timeout /t 3 >nul
goto SYSTEM_RESTORE_MENU

:RESTORE_NOT_FOUND
call :PRINT_HEADER
color 0C
echo     System Restore (rstrui.exe) not found.
echo     Opening System Protection settings instead...
start "" systempropertiesprotection
echo.
echo     ─────────────────────────────────────
echo     Instructions:
echo     1. Open 'System Protection' menu.
echo     2. Click 'System Restore...' button.
echo     ─────────────────────────────────────
echo.
pause
goto SYSTEM_RESTORE_MENU

:: ============================================================================
:: CPU OPTIMIZATION
:: ============================================================================
:CPU_MENU
title CPU Optimization
call :PRINT_HEADER
color 0F
echo     CPU OPTIMIZATION (%CPU_TYPE%)
echo.
echo     [1] Applying TGP (Ultimate Performance)
echo     [2] Set CPU and Network Priority for Gaming
echo     [3] Revert CPU and Network Priority to Default
if "%CPU_TYPE%"=="AMD" echo     [A] AMD CPU Boost Optimization
echo     [R] Revert All CPU Settings to Default
echo     [B] Back to Main Menu
echo.
set /p cpu_choice="Select option: "

if "%cpu_choice%"=="1" goto SMART_POWER_PLAN
if /i "%cpu_choice%"=="A" if "%CPU_TYPE%"=="AMD" goto CPU_AMD_BOOST
if "%cpu_choice%"=="2" goto CPU_NET_PRIORITY_ON
if "%cpu_choice%"=="3" goto CPU_NET_PRIORITY_OFF
if /i "%cpu_choice%"=="R" goto CPU_REVERT
if /i "%cpu_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto CPU_MENU

:: ==============================================================
:: TGP (TECH GAMEPLAY PERFORMANCE)
:: ==============================================================
:SMART_POWER_PLAN
call :PRINT_HEADER
color 0E
echo     Importing TGP...
echo.

:: check if file exists
if not exist "C:\TGO\TGP.pow" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] TGP.pow not found in C:\TGO\
    echo     Please ensure the download was successful.
    pause
    goto CPU_MENU
)

powercfg -import "C:\TGO\TGP.pow" 00000000-0000-0000-0000-000000000000 >nul 2>&1
powercfg -setactive 00000000-0000-0000-0000-000000000000 >nul 2>&1

:: check if activated
powercfg /getactivescheme | find "00000000-0000-0000-0000-000000000000" >nul
if %errorlevel%==0 (
    call :WRITE_LOG "TGP Ultimate Performance power plan activated"
    call :PRINT_HEADER
    color 0A
    echo     ─────────────────────────────────────────────
    echo     [SUCCESS] TGP ULTIMATE PERFORMANCE ACTIVATED!
    echo     ─────────────────────────────────────────────
    echo.
    echo     Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
) else (
    call :WRITE_LOG "High Performance power plan activated"
    call :PRINT_HEADER
    color 0C
    echo     [WARNING] Failed to activate TGP. Trying default High Performance...
    powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    echo     [SUCCESS] High Performance Activated.
    echo     Back to CPU Optimization menu...
    timeout /t 3 >nul
    goto CPU_MENU
)

echo     Back to CPU Optimization menu...
timeout /t 3 >nul
goto CPU_MENU

:CPU_AMD_BOOST
call :PRINT_HEADER
color 0E
echo     Applying AMD CPU Boost Optimization...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Throttle" /v "PerfEnablePackageIdle" /t REG_DWORD /d 0 /f >nul 2>&1
call :WRITE_LOG "AMD CPU Boost optimization applied"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] AMD CPU Boost Applied.
echo.
echo     Back to CPU menu...
timeout /t 3 >nul
goto CPU_MENU

:CPU_NET_PRIORITY_ON
call :PRINT_HEADER
color 0E
echo     Applying CPU and Network Priority for Gaming...
echo.
echo     [1/2] Setting SystemResponsiveness to 0 (Maximum CPU priority for foreground)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 0 /f >nul 2>&1
if %errorlevel% equ 0 ( echo     [OK] ) else ( echo     [FAILED] )

echo.
echo     [2/2] Setting NetworkThrottlingIndex to 0xffffffff (Disable network throttling)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 0xffffffff /f >nul 2>&1
if %errorlevel% equ 0 ( echo     [OK] ) else ( echo     [FAILED] )

call :WRITE_LOG "CPU & Network priority set for gaming (SystemResponsiveness=0, NetworkThrottlingIndex=ffffffff)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] CPU and Network priority tweaks applied!
echo.
echo     Note: These tweaks give maximum priority to games but may cause
echo     background tasks (downloads, streaming) to become sluggish.
echo.
echo     Back to CPU Menu...
timeout /t 5 >nul
goto CPU_MENU

:CPU_NET_PRIORITY_OFF
call :PRINT_HEADER
color 0E
echo     Reverting CPU and Network Priority to Default...
echo.
echo     [1/2] Restoring SystemResponsiveness to 20
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 20 /f >nul 2>&1
if %errorlevel% equ 0 ( echo     [OK] ) else ( echo     [FAILED] )

echo.
echo     [2/2] Restoring NetworkThrottlingIndex to 10
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 10 /f >nul 2>&1
if %errorlevel% equ 0 ( echo     [OK] ) else ( echo     [FAILED] )

call :WRITE_LOG "CPU & Network priority reverted to default (SystemResponsiveness=20, NetworkThrottlingIndex=10)"

call :PRINT_HEADER
color 0A
echo     [SUCCESS] CPU and Network priority restored to default!
echo.
echo     Back to CPU Menu...
timeout /t 3 >nul
goto CPU_MENU

:CPU_REVERT
call :PRINT_HEADER
color 0E
powercfg -restoredefaultschemes
if "%CPU_TYPE%"=="AMD" reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Throttle" /f >nul 2>&1
call :WRITE_LOG "All CPU settings reverted to default"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] CPU Settings Reverted.
echo.
echo     Back to CPU menu...
timeout /t 3 >nul
goto CPU_MENU

:: ============================================================================
:: GPU OPTIMIZATION
:: ============================================================================
:GPU_MENU
title GPU Optimization
call :PRINT_HEADER
color 0F
echo     GPU OPTIMIZATION (%OPTIMIZE_GPU%)
echo.
echo     [1] Enable HAGS (Hardware Accelerated GPU Scheduling)
echo     [2] Optimize Game Mode (%OS_NAME%)
if "%OPTIMIZE_GPU%"=="NVIDIA" echo     [N] NVIDIA GPU Tweaks
if "%OPTIMIZE_GPU%"=="AMD" echo     [A] AMD GPU Tweaks
if "%OPTIMIZE_GPU%"=="INTEL" echo     [I] INTEL GPU Tweaks
if "%OPTIMIZE_GPU%"=="NVIDIA" echo     [R] Revert NVIDIA GPU Settings to Default
if "%OPTIMIZE_GPU%"=="AMD" echo     [R] Revert AMD GPU Settings to Default
if "%OPTIMIZE_GPU%"=="INTEL" echo     [R] Revert INTEL GPU Settings to Default
echo     [B] Back to Main Menu
echo.
set /p gpu_choice="Select option: "

if "%gpu_choice%"=="1" goto GPU_HAGS_ON
if "%gpu_choice%"=="2" goto GPU_GAMEMODE
if /i "%gpu_choice%"=="N" if "%OPTIMIZE_GPU%"=="NVIDIA" goto GPU_NVIDIA_TWEAK
if /i "%gpu_choice%"=="A" if "%OPTIMIZE_GPU%"=="AMD" goto GPU_AMD_TWEAK
if /i "%gpu_choice%"=="I" if "%OPTIMIZE_GPU%"=="INTEL" goto GPU_INTEL_TWEAK
if /i "%gpu_choice%"=="R" goto GPU_REVERT
if /i "%gpu_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto GPU_MENU

:GPU_HAGS_ON
call :PRINT_HEADER
color 0E
echo     Enabling HAGS...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f >nul 2>&1
call :WRITE_LOG "Hardware Accelerated GPU Scheduling (HAGS) enabled"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] HAGS Enabled. Restart Required
echo.
echo     Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:GPU_GAMEMODE
call :PRINT_HEADER
color 0E
echo     Optimizing Game Mode For (%OS_NAME%)...
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d %GAME_MODE_VALUE% /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d %GAME_MODE_VALUE% /f >nul 2>&1
call :WRITE_LOG "Game Mode set to %GAME_MODE_TARGET% for %OS_NAME%"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Game Mode Set to %GAME_MODE_TARGET%
echo.
echo     Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:GPU_NVIDIA_TWEAK
call :PRINT_HEADER
color 0E
echo     Searching for NVIDIA GPU Registry Keys...
set FOUND_NVIDIA=0
for /f "delims=" %%p in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /f "NVIDIA" ^| find "HKEY"') do (
    echo     Applying NVIDIA tweaks to: %%p
    set FOUND_NVIDIA=1
    reg add "%%p" /v "DisableDynamicPstate" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%%p" /v "RMHdcpKeyglobZero" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%%p" /v "PreferSystemMemoryContiguous" /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "%%p" /v "D3PCLatency" /t REG_DWORD /d 1 /f >nul 2>&1
)

if "%FOUND_NVIDIA%"=="0" (
    echo     [INFO] No NVIDIA GPU keys found in registry.
) else (
    echo.
    echo     Apply Global NVIDIA Power Tweaks...
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
    echo     [SUCCESS] NVIDIA GPU Optimization Applied.
)
call :WRITE_LOG "NVIDIA GPU tweaks applied (power management, latency settings, service disabled)"
pause
goto GPU_MENU

:GPU_AMD_TWEAK
call :PRINT_HEADER
color 0E
echo     Searching for AMD GPU Registry Keys...
set FOUND_AMD=0

for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" 2^>nul ^| find "HKEY"') do (
    reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "AMD ATI Radeon" >nul
    if !errorlevel! equ 0 (
        echo     Applying AMD Tweaks to: %%k
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

if "%FOUND_AMD%"=="0" echo     [INFO] No AMD GPU keys found.
if "%FOUND_AMD%"=="1" echo     [SUCCESS] AMD GPU Optimization Applied.
call :WRITE_LOG "AMD GPU tweaks applied (ULPS disabled, power management off, UMD optimizations)"
pause
goto GPU_MENU

:GPU_INTEL_TWEAK
call :PRINT_HEADER
color 0E
echo     Searching for INTEL GPU Registry Keys...
set FOUND_INTEL=0
for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" 2^>nul ^| find "HKEY"') do (
    reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "Intel" >nul
    if !errorlevel! equ 0 (
        echo     Applying INTEL Tweaks to: %%k
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

if "%FOUND_INTEL%"=="0" echo     [INFO] No Intel GPU keys found.
if "%FOUND_INTEL%"=="1" echo     [SUCCESS] Intel GPU Optimization Applied.
call :WRITE_LOG "Intel GPU tweaks applied (power management, dedicated segment size, latency settings)"
pause
goto GPU_MENU

:GPU_REVERT
call :PRINT_HEADER
color 0E
echo     Detected GPUs: %GPU_MODEL_DETAIL%
timeout /t 3 >nul
echo     Reverting %OPTIMIZE_GPU% GPU Tweaks...
rem Revert HAGS
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 1 /f >nul 2>&1
rem Revert Game Mode (Delete keys or set to 0)
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 0 /f >nul 2>&1
if "%OPTIMIZE_GPU%"=="NVIDIA" (
    echo     Reverting NVIDIA Tweaks...
    for /f "delims=" %%p in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s /f "NVIDIA" ^| find "HKEY"') do (
        echo     Reverting tweaks on: %%p
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
if "%OPTIMIZE_GPU%"=="AMD" (
    echo     Reverting AMD Tweaks...
    for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" 2^>nul ^| find "HKEY"') do (
        reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "AMD ATI Radeon" >nul
        if !errorlevel! equ 0 (
            echo     Reverting tweaks on: %%k
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
    echo     Reverting Intel Tweaks...
    for /f "delims=" %%k in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" 2^>nul ^| find "HKEY"') do (
        reg query "%%k" /v "DriverDesc" 2>nul | findstr /i "Intel" >nul
        if !errorlevel! equ 0 (
            echo     Reverting tweaks on: %%k
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
call :WRITE_LOG "GPU settings reverted to default (HAGS, Game Mode, vendor-specific tweaks removed)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] GPU Settings Reverted.
echo.
echo     Back to GPU Optimization menu...
timeout /t 3 >nul
goto GPU_MENU

:: ============================================================================
:: CHANGELOG
:: ============================================================================
:CHANGELOG
title Changelog
call :PRINT_HEADER
color 0F
echo     CHANGELOG
echo.
echo     [v2.1.0]
echo       + Added Services Optimization Menu.
echo       + Updated TGP Power Plan for better performance. (redownload all the resources first)
echo.
echo     [v2.0.1]
echo       + Fixed Storage Type Detection for some models.
echo.
echo     [v2.0.0]
echo       + Completely redesigned clean and modern UI.
echo       + Auto-detect RAM size and Storage type. (SSD/HDD)
echo       + Improved hardware detection accuracy.
echo       + Optimization logging system. (C:\TGO\logs\TGO_Log.txt)
echo       + Better organized menus with clear recommendations.
echo       + Premium visual experience with consistent styling.
echo       + And much more...
echo.
echo     [v1.5.6]
echo       + Added Redownload All Resources Menu.
echo       + Improved Download Reliability.
echo.
echo     [v1.5.5]
echo       + Added Additional Tweaks Menu.
echo       + Updated GPU Optimization with more tweaks.
echo       + Updated Clean All Temporary Files.
echo       + Fixed Hardware Detection for more models.
echo.
echo     [v1.4.1]
echo       + Fixed AMD GPU Detection for some models.
echo.
echo     [v1.4.0]
echo       + Added Hardware Detection (OS, CPU, GPU)
echo       + Added CPU Optimization Menu.
echo       + Added GPU Optimization Menu.
echo.
echo     [v1.0.1]
echo       + Added a startup safety check.
echo       + Minor fixes and stability improvements.
echo.
echo     [v1.0.0]
echo       + Initial Release of Tech Gameplay Optimizer (TGO)
echo.
echo Press any key to continue...
pause >nul
goto MAIN_MENU

:: ============================================================================
:: ADDITIONAL TWEAKS
:: ============================================================================
:ADDITIONAL_TWEAKS
title Additional Tweaks
call :PRINT_HEADER
color 0F
echo     ADDITIONAL TWEAKS
echo.
echo     [1] Turn on or off Windows Update
echo     [2] Turn off Windows Security (Permanently)
echo     [3] Turn off all Windows Animations
echo     [4] Delete all useless apps via third-party tool
echo     [5] Turn on or off User Account Control
echo     [6] Turn on or off Transparency Effects and Color on Title Bars
echo     [B] Back to Main Menu
echo.
set /p add_choice="Select option: "

if "%add_choice%"=="1" goto WINDOWS_UPDATE
if "%add_choice%"=="2" goto WINDOWS_SECURITY
if "%add_choice%"=="3" goto ADVANCED_SYSTEM_SETTINGS
if "%add_choice%"=="4" goto DELETE_APPS
if "%add_choice%"=="5" goto UAC
if "%add_choice%"=="6" goto VISUAL_EFFECTS_MENU
if /i "%add_choice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto ADDITIONAL_TWEAKS

:ADVANCED_SYSTEM_SETTINGS
call :PRINT_HEADER
color 0E
echo     Follow this step to disable all the animations
echo.
echo     1. Performance Options window will be open shortly...
echo     2. Choose 'Adjust for best performance'.
echo     3. Check the box 'Show thumbnails instead of icons', 'Smooth edges of screen fonts',
echo     and 'Show window contents while dragging'.
echo     4. After that, click 'Apply' and then 'OK' to save the settings.
echo     5. CLOSE the Performance Options window to finish this step.
echo.

start /wait "" %windir%\System32\SystemPropertiesPerformance.exe
call :WRITE_LOG "Adjusted visual effects for best performance (user modified Performance Options)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Performance Options window closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:DOWNLOAD_RESOURCES
cls
color 0E
echo.
echo     Downloading all the resources... (Completely Safe)
echo.

if not exist "C:\TGO\Disable Windows Security Permanent" md "C:\TGO\Disable Windows Security Permanent"
if not exist "C:\TGO\UAC Off" md "C:\TGO\UAC Off"
if not exist "C:\TGO\UAC On" md "C:\TGO\UAC On"

echo     [1/9] Downloading.
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\off.bat" "https://raw.githubusercontent.com/tehgeii/TGOResources/refs/heads/main/Disable%%20Windows%%20Security%%20Permanent/off.bat" >nul 2>&1  
echo.
echo     [2/9] Downloading..
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\off.reg" "https://raw.githubusercontent.com/tehgeii/TGOResources/main/Disable%%20Windows%%20Security%%20Permanent/off.reg" >nul 2>&1  
echo.
echo     [3/9] Downloading...
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\PowerRun.exe" "https://raw.githubusercontent.com/tehgeii/TGOResources/refs/heads/main/Disable%%20Windows%%20Security%%20Permanent/PowerRun.exe" >nul 2>&1  
echo.
echo     [4/9] Downloading....
curl -g -k -L -# -o "C:\TGO\UAC Off\off.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20Off/off.bat" >nul 2>&1  
echo.
echo     [5/9] Downloading.....
curl -g -k -L -# -o "C:\TGO\UAC On\on without black screen.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20On/on%%20without%%20black%%20screen.bat" >nul 2>&1  
echo.
echo     [6/9] Downloading......
curl -g -k -L -# -o "C:\TGO\UAC On\on.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20On/on.bat" >nul 2>&1  
echo.
echo     [7/9] Downloading.......
curl -g -k -L -# -o "C:\TGO\geek.exe" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/geek.exe" >nul 2>&1  
echo.
echo     [8/9] Downloading........
curl -g -k -L -# -o "C:\TGO\TGP.pow" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/TGP.pow" >nul 2>&1  
echo.
echo     [9/9] Downloading.........
curl -g -k -L -# -o "C:\TGO\Wub_x64.exe" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/Wub_x64.exe" >nul 2>&1  

echo.
echo     All resources downloaded successfully.
timeout /t 3 >nul
cls
goto STARTUP_RESTORE_CHECK

:REDOWNLOAD
title Redownload Resources
call :PRINT_HEADER
color 0E
echo     Redownloading all the resources... (Completely Safe)
echo.

if not exist "C:\TGO\Disable Windows Security Permanent" md "C:\TGO\Disable Windows Security Permanent"
if not exist "C:\TGO\UAC Off" md "C:\TGO\UAC Off"
if not exist "C:\TGO\UAC On" md "C:\TGO\UAC On"

echo     [1/9] Downloading.
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\off.bat" "https://raw.githubusercontent.com/tehgeii/TGOResources/refs/heads/main/Disable%%20Windows%%20Security%%20Permanent/off.bat" >nul 2>&1  
echo.
echo     [2/9] Downloading..
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\off.reg" "https://raw.githubusercontent.com/tehgeii/TGOResources/main/Disable%%20Windows%%20Security%%20Permanent/off.reg" >nul 2>&1  
echo.
echo     [3/9] Downloading...
curl -g -k -L -# -o "C:\TGO\Disable Windows Security Permanent\PowerRun.exe" "https://raw.githubusercontent.com/tehgeii/TGOResources/refs/heads/main/Disable%%20Windows%%20Security%%20Permanent/PowerRun.exe" >nul 2>&1  
echo.
echo     [4/9] Downloading....
curl -g -k -L -# -o "C:\TGO\UAC Off\off.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20Off/off.bat" >nul 2>&1  
echo.
echo     [5/9] Downloading.....
curl -g -k -L -# -o "C:\TGO\UAC On\on without black screen.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20On/on%%20without%%20black%%20screen.bat" >nul 2>&1  
echo.
echo     [6/9] Downloading......
curl -g -k -L -# -o "C:\TGO\UAC On\on.bat" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/UAC%%20On/on.bat" >nul 2>&1  
echo.
echo     [7/9] Downloading.......
curl -g -k -L -# -o "C:\TGO\geek.exe" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/geek.exe" >nul 2>&1  
echo.
echo     [8/9] Downloading........
curl -g -k -L -# -o "C:\TGO\TGP.pow" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/TGP.pow" >nul 2>&1  
echo.
echo     [9/9] Downloading.........
curl -g -k -L -# -o "C:\TGO\Wub_x64.exe" "https://github.com/tehgeii/TGOResources/raw/refs/heads/main/Wub_x64.exe" >nul 2>&1  

echo.
echo     All resources downloaded successfully.
timeout /t 3 >nul
goto MAIN_MENU

:WINDOWS_UPDATE
call :PRINT_HEADER
color 0E
echo     Windows Update Blocker Guide
echo.
echo     1. Choose 'Disable Updates' (with the option checked) to turn off Windows Update.
echo     2. Choose 'Enable Updates' to turn on Windows Update.
echo     3. Then hit 'Apply Now' button to save the settings.
echo     4. CLOSE the WUB window to finish this step.
echo.
:: check if file exists
if not exist "C:\TGO\Wub_x64.exe" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] Wub_x64.exe not found in C:\TGO\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGO\Wub_x64.exe"
call :WRITE_LOG "Windows Update settings changed via WUB (Windows Update Blocker)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Windows Update Blocker closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:WINDOWS_SECURITY
call :PRINT_HEADER
color 0E
echo     Waiting for all the processes related to Windows Security to be completed...
echo.

if not exist "C:\TGO\Disable Windows Security Permanent\PowerRun.exe" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] PowerRun.exe not found in C:\TGO\Disable Windows Security Permanent\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

:: Set Path variabel
set "BASE_PATH=C:\TGO\Disable Windows Security Permanent"
set "PWR_EXE=%BASE_PATH%\PowerRun.exe"
set "OFF_BAT=%BASE_PATH%\off.bat"
set "OFF_REG=%BASE_PATH%\off.reg"

powershell -Command "Start-Process -FilePath '%PWR_EXE%' -ArgumentList '\"%OFF_BAT%\"' -Wait"
powershell -Command "Start-Process -FilePath '%PWR_EXE%' -ArgumentList 'regedit.exe', '/s', '\"%OFF_REG%\"' -Wait"
call :WRITE_LOG "Windows Security permanently disabled via PowerRun and registry"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] Windows Security has been turned off permanently. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:DELETE_APPS
call :PRINT_HEADER
color 0E
echo     Delete Apps Guide
echo.
echo     1. geek will be launched shortly...
echo     2. Inside geek, select the apps you want to delete.
echo     3. After selecting, right click on the selected apps and choose 'Uninstall'.
echo     4. After the uninstallation is done, CLOSE geek to finish this step.
echo.
:: check if file exists
if not exist "C:\TGO\geek.exe" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] geek not found in C:\TGO\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGO\geek.exe"
call :WRITE_LOG "Uninstalled applications using geek (user removed selected apps)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] geek has been closed. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UAC
call :PRINT_HEADER
color 0F
echo     Do you want to turn on or off User Account Control (UAC)?
echo.
echo     [1] Turn ON UAC
echo     [2] Turn OFF UAC
echo.
set /p uac_choice="Select option: "

if "%uac_choice%"=="1" goto UAC_ON
if "%uac_choice%"=="2" goto UAC_OFF

echo Invalid selection
echo Press any key to continue...
pause >nul
goto UAC
echo.

:UAC_OFF
if not exist "C:\TGO\UAC Off\off.bat" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] off.bat not found in C:\TGO\UAC Off\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)

start /wait "" "C:\TGO\UAC Off\off.bat"
call :WRITE_LOG "User Account Control (UAC) turned OFF"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] UAC has been turned off. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UAC_ON
if not exist "C:\TGO\UAC On\on.bat" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] on.bat not found in C:\TGO\UAC On\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)
start /wait "" "C:\TGO\UAC On\on.bat"

:UACF
call :PRINT_HEADER
color 0F
echo     Do you want to remove the black screen when turning on UAC?
echo.
echo     [1] Yes
echo     [2] No
echo.
set /p uacf_choice="Select option: "

if "%uacf_choice%"=="1" goto UACF_ON
if "%uacf_choice%"=="2" goto UACF_OFF

echo Invalid selection
echo Press any key to continue...
pause >nul
goto UACF

:UACF_ON
if not exist "C:\TGO\UAC On\on without black screen.bat" (
    call :PRINT_HEADER
    color 0C
    echo     [FAILED] on without black screen.bat not found in C:\TGO\UAC On\
    echo     Please ensure the download was successful.
    pause
    goto ADDITIONAL_TWEAKS
)
start /wait "" "C:\TGO\UAC On\on without black screen.bat"
call :WRITE_LOG "User Account Control (UAC) turned ON (without black screen)"
call :PRINT_HEADER
color 0A
echo     [SUCCESS] UAC has been turned on. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:UACF_OFF
call :PRINT_HEADER
color 0A
echo     [SUCCESS] UAC has been turned on. Returning to menu...
timeout /t 3 >nul
goto ADDITIONAL_TWEAKS

:VISUAL_EFFECTS_MENU
call :PRINT_HEADER
color 0F
echo     VISUAL EFFECTS SETTINGS
echo.
echo     [1] Turn ON Transparency Effects
echo     [2] Turn OFF Transparency Effects
echo     [3] Turn ON Color on Title Bars
echo     [4] Turn OFF Color on Title Bars
echo     [B] Back to Additional Tweaks
echo.
set /p visual_choice="Select option: "

if "%visual_choice%"=="1" goto TURN_ON_TRANSPARENCY
if "%visual_choice%"=="2" goto TURN_OFF_TRANSPARENCY
if "%visual_choice%"=="3" goto TURN_ON_TITLEBAR_COLOR
if "%visual_choice%"=="4" goto TURN_OFF_TITLEBAR_COLOR
if /i "%visual_choice%"=="B" goto ADDITIONAL_TWEAKS

echo Invalid selection
echo Press any key to continue...
pause >nul
goto VISUAL_EFFECTS_MENU

:TURN_ON_TRANSPARENCY
call :PRINT_HEADER
color 0E
echo     Enabling Transparency Effects...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 1 /f >nul 2>&1
if %errorlevel% equ 0 (
    call :WRITE_LOG "Transparency Effects has been turned ON"
    call :PRINT_HEADER
    color 0A
    echo     [SUCCESS] Transparency Effects turned ON. Returning to menu...
) else (
    call :PRINT_HEADER
    color 0C
    echo     [ERROR] Failed to modify registry. Returning to menu...
)
timeout /t 3 >nul
goto VISUAL_EFFECTS_MENU

:TURN_OFF_TRANSPARENCY
call :PRINT_HEADER
color 0E
echo     Disabling Transparency Effects...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f >nul 2>&1
if %errorlevel% equ 0 (
    call :WRITE_LOG "Transparency Effects has been turned OFF"
    call :PRINT_HEADER
    color 0A
    echo     [SUCCESS] Transparency Effects turned OFF. Returning to menu...
) else (
    call :PRINT_HEADER
    color 0C
    echo     [ERROR] Failed to modify registry. Returning to menu...
)
timeout /t 3 >nul
goto VISUAL_EFFECTS_MENU

:TURN_ON_TITLEBAR_COLOR
call :PRINT_HEADER
color 0E
echo     Enabling Color on Title Bars...
reg add "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "ColorPrevalence" /t REG_DWORD /d 1 /f >nul 2>&1
if %errorlevel% equ 0 (
    call :WRITE_LOG "Color on Title Bars has been turned ON"
    call :PRINT_HEADER
    color 0A
    echo     [SUCCESS] Color on title bars turned ON. A restart may be required.
) else (
    call :PRINT_HEADER
    color 0C
    echo     [ERROR] Failed to modify registry. Returning to menu...
)
timeout /t 3 >nul
goto VISUAL_EFFECTS_MENU

:TURN_OFF_TITLEBAR_COLOR
call :PRINT_HEADER
color 0E
echo     Disabling Color on Title Bars...
reg add "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v "ColorPrevalence" /t REG_DWORD /d 0 /f >nul 2>&1
if %errorlevel% equ 0 (
    call :WRITE_LOG "Color on Title Bars has been turned OFF"
    call :PRINT_HEADER
    color 0A
    echo     [SUCCESS] Color on title bars turned OFF. A restart may be required.
) else (
    call :PRINT_HEADER
    color 0C
    echo     [ERROR] Failed to modify registry. Returning to menu...
)
timeout /t 3 >nul
goto VISUAL_EFFECTS_MENU

:: ============================================================================
:: SERVICES OPTIMIZATION
:: ============================================================================
:SERVICES_OPTIMIZATION_MENU
title Services Optimization
call :PRINT_HEADER
color 0F
echo     SERVICES OPTIMIZATION
echo.
echo     [1]  Basic Optimization     (Safe for everyone)
echo     [2]  Standard Optimization  (Recommended for gamers)
echo     [3]  Advanced Optimization  (Extreme Tweaks - Read Info first)
echo     [4]  Revert to Default
echo.
echo     [I]  Mode Info ^& Explanation
echo     [B]  Back to Main Menu
echo.
set /p svcchoice="Select option: "

if "%svcchoice%"=="1" goto SERVICES_BASIC
if "%svcchoice%"=="2" goto SERVICES_STANDARD
if "%svcchoice%"=="3" goto SERVICES_ADVANCED
if "%svcchoice%"=="4" goto SERVICES_REVERT
if /i "%svcchoice%"=="I" goto SERVICES_INFO
if /i "%svcchoice%"=="B" goto MAIN_MENU

echo Invalid selection
echo Press any key to continue...
pause >nul
goto SERVICES_OPTIMIZATION_MENU

:SERVICES_INFO
call :PRINT_HEADER
color 0F
echo     MODE INFO ^& EXPLANATION SERVICES OPTIMIZATION
echo.
echo     Basic Mode: (Safe for everyone)
echo     - Disables Telemetry, Tracking, and Microsoft Diagnostics.
echo     - Disables Bloatware services (RetailDemo, WAP Push).
echo     - Useful for reducing background processes without damaging important features.
echo.
echo     Standard Mode: (Recommended for gamers)
echo     - Includes all Basic Mode features.
echo     - Disables rarely used services: Print Spooler (printer), Offline 
echo       Files, Remote Registry, and Superfetch (highly recommended if 
echo       using SSD).
echo     - Disables Windows Notifications (Toast/Push) and Messaging.
echo     - Info: If you need to print or see notifications, use Revert mode later.
echo.
echo     Advanced Mode: (EXTREME - Use at your own risk)
echo     - Includes all Standard Mode features.
echo     - Disables Windows Update, Windows Defender (Security), Xbox Services,
echo       and several other services.
echo     - Info: NOT RECOMMENDED for daily use because it is very vulnerable
echo       to viruses and cannot install games from Microsoft Store/Xbox.
echo.
echo     Revert to Default:
echo     - Restore all disabled services to their original Windows settings.
echo     - Use this if any features suddenly stop working.
echo.
echo     Press any key to go back...
pause >nul
goto SERVICES_OPTIMIZATION_MENU

:SERVICES_BASIC
call :PRINT_HEADER
color 0E
echo     Applying Basic Services Optimization...
echo     Please wait...
echo.
sc stop DoSvc > nul 2>&1
sc config DoSvc start= disabled > nul 2>&1
sc stop diagsvc > nul 2>&1
sc config diagsvc start= disabled > nul 2>&1
sc stop DPS > nul 2>&1
sc config DPS start= disabled > nul 2>&1
sc stop dmwappushservice > nul 2>&1
sc config dmwappushservice start= disabled > nul 2>&1
sc stop MapsBroker > nul 2>&1
sc config MapsBroker start= disabled > nul 2>&1
sc stop RetailDemo > nul 2>&1
sc config RetailDemo start= disabled > nul 2>&1
sc stop WdiServiceHost > nul 2>&1
sc config WdiServiceHost start= disabled > nul 2>&1
sc stop WdiSystemHost > nul 2>&1
sc config WdiSystemHost start= disabled > nul 2>&1
sc stop DiagTrack > nul 2>&1
sc config DiagTrack start= disabled > nul 2>&1

call :WRITE_LOG "Applied Basic Services Optimization"
color 0A
echo     [SUCCESS] Basic Optimization Applied!
timeout /t 3 >nul
goto SERVICES_OPTIMIZATION_MENU

:SERVICES_STANDARD
call :PRINT_HEADER
color 0E
echo     Applying Standard Services Optimization...
echo     Please wait...
echo.
:: Apply Basic first
sc stop DoSvc > nul 2>&1
sc config DoSvc start= disabled > nul 2>&1
sc stop diagsvc > nul 2>&1
sc config diagsvc start= disabled > nul 2>&1
sc stop DPS > nul 2>&1
sc config DPS start= disabled > nul 2>&1
sc stop dmwappushservice > nul 2>&1
sc config dmwappushservice start= disabled > nul 2>&1
sc stop MapsBroker > nul 2>&1
sc config MapsBroker start= disabled > nul 2>&1
sc stop RetailDemo > nul 2>&1
sc config RetailDemo start= disabled > nul 2>&1
sc stop WdiServiceHost > nul 2>&1
sc config WdiServiceHost start= disabled > nul 2>&1
sc stop WdiSystemHost > nul 2>&1
sc config WdiSystemHost start= disabled > nul 2>&1
sc stop DiagTrack > nul 2>&1
sc config DiagTrack start= disabled > nul 2>&1

:: Standard specific
sc stop Spooler > nul 2>&1
sc config Spooler start= disabled > nul 2>&1
sc stop fhsvc > nul 2>&1
sc config fhsvc start= disabled > nul 2>&1
sc stop RemoteRegistry > nul 2>&1
sc config RemoteRegistry start= disabled > nul 2>&1
sc stop TrkWks > nul 2>&1
sc config TrkWks start= disabled > nul 2>&1
sc stop SysMain > nul 2>&1
sc config SysMain start= disabled > nul 2>&1
sc stop lfsvc > nul 2>&1
sc config lfsvc start= disabled > nul 2>&1
sc stop CscService > nul 2>&1
sc config CscService start= disabled > nul 2>&1
sc stop PhoneSvc > nul 2>&1
sc config PhoneSvc start= disabled > nul 2>&1
sc stop WalletService > nul 2>&1
sc config WalletService start= disabled > nul 2>&1
sc stop TermService > nul 2>&1
sc config TermService start= disabled > nul 2>&1
sc stop SessionEnv > nul 2>&1
sc config SessionEnv start= disabled > nul 2>&1
sc stop UmRdpService > nul 2>&1
sc config UmRdpService start= disabled > nul 2>&1

:: Disable User Services via Registry (Basic + Standard)
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WpnUserService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1

call :WRITE_LOG "Applied Standard Services Optimization"
color 0A
echo     [SUCCESS] Standard Optimization Applied!
timeout /t 3 >nul
goto SERVICES_OPTIMIZATION_MENU

:SERVICES_ADVANCED
call :PRINT_HEADER
color 0C
echo     [WARNING] Applying Advanced Services Optimization...
echo     This will disable Windows Update and Windows Defender!
echo     Please wait...
echo.
:: Apply Standard first
sc stop DoSvc > nul 2>&1
sc config DoSvc start= disabled > nul 2>&1
sc stop diagsvc > nul 2>&1
sc config diagsvc start= disabled > nul 2>&1
sc stop DPS > nul 2>&1
sc config DPS start= disabled > nul 2>&1
sc stop dmwappushservice > nul 2>&1
sc config dmwappushservice start= disabled > nul 2>&1
sc stop MapsBroker > nul 2>&1
sc config MapsBroker start= disabled > nul 2>&1
sc stop RetailDemo > nul 2>&1
sc config RetailDemo start= disabled > nul 2>&1
sc stop WdiServiceHost > nul 2>&1
sc config WdiServiceHost start= disabled > nul 2>&1
sc stop WdiSystemHost > nul 2>&1
sc config WdiSystemHost start= disabled > nul 2>&1
sc stop DiagTrack > nul 2>&1
sc config DiagTrack start= disabled > nul 2>&1
sc stop Spooler > nul 2>&1
sc config Spooler start= disabled > nul 2>&1
sc stop fhsvc > nul 2>&1
sc config fhsvc start= disabled > nul 2>&1
sc stop RemoteRegistry > nul 2>&1
sc config RemoteRegistry start= disabled > nul 2>&1
sc stop TrkWks > nul 2>&1
sc config TrkWks start= disabled > nul 2>&1
sc stop SysMain > nul 2>&1
sc config SysMain start= disabled > nul 2>&1
sc stop lfsvc > nul 2>&1
sc config lfsvc start= disabled > nul 2>&1
sc stop CscService > nul 2>&1
sc config CscService start= disabled > nul 2>&1
sc stop PhoneSvc > nul 2>&1
sc config PhoneSvc start= disabled > nul 2>&1
sc stop WalletService > nul 2>&1
sc config WalletService start= disabled > nul 2>&1
sc stop TermService > nul 2>&1
sc config TermService start= disabled > nul 2>&1
sc stop SessionEnv > nul 2>&1
sc config SessionEnv start= disabled > nul 2>&1
sc stop UmRdpService > nul 2>&1
sc config UmRdpService start= disabled > nul 2>&1

:: Advanced specific
sc stop wuauserv > nul 2>&1
sc config wuauserv start= disabled > nul 2>&1
sc stop UsoSvc > nul 2>&1
sc config UsoSvc start= disabled > nul 2>&1
sc stop BITS > nul 2>&1
sc config BITS start= disabled > nul 2>&1
sc stop WaaSMedicSvc > nul 2>&1
sc config WaaSMedicSvc start= disabled > nul 2>&1
sc stop WinDefend > nul 2>&1
sc config WinDefend start= disabled > nul 2>&1
sc stop wscsvc > nul 2>&1
sc config wscsvc start= disabled > nul 2>&1
sc stop Sense > nul 2>&1
sc config Sense start= disabled > nul 2>&1
sc stop WdNisSvc > nul 2>&1
sc config WdNisSvc start= disabled > nul 2>&1
sc stop wmiApSrv > nul 2>&1
sc config wmiApSrv start= disabled > nul 2>&1
sc stop XboxGipSvc > nul 2>&1
sc config XboxGipSvc start= disabled > nul 2>&1
sc stop xbgm > nul 2>&1
sc config xbgm start= disabled > nul 2>&1
sc stop XblAuthManager > nul 2>&1
sc config XblAuthManager start= disabled > nul 2>&1
sc stop XblGameSave > nul 2>&1
sc config XblGameSave start= disabled > nul 2>&1
sc stop XboxNetApiSvc > nul 2>&1
sc config XboxNetApiSvc start= disabled > nul 2>&1

:: Disable User Services via Registry (Basic + Standard + Advanced)
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WpnUserService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BluetoothUserService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CDPUserSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CaptureService" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ConsentUxUserSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\OneSyncSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UserDataSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UnistoreSvc" /v Start /t REG_DWORD /d 4 /f > nul 2>&1

call :WRITE_LOG "Applied Advanced Services Optimization"
color 0A
echo     [SUCCESS] Advanced Optimization Applied!
timeout /t 3 >nul
goto SERVICES_OPTIMIZATION_MENU

:SERVICES_REVERT
call :PRINT_HEADER
color 0E
echo     Reverting Services to Default...
echo     Please wait...
echo.
sc config DoSvc start= delayed-auto > nul 2>&1
sc config diagsvc start= demand > nul 2>&1
sc config DPS start= auto > nul 2>&1
sc config dmwappushservice start= demand > nul 2>&1
sc config MapsBroker start= delayed-auto > nul 2>&1
sc config RetailDemo start= demand > nul 2>&1
sc config WdiServiceHost start= demand > nul 2>&1
sc config WdiSystemHost start= demand > nul 2>&1
sc config DiagTrack start= auto > nul 2>&1
sc config Spooler start= auto > nul 2>&1
sc config fhsvc start= demand > nul 2>&1
sc config RemoteRegistry start= disabled > nul 2>&1
sc config TrkWks start= auto > nul 2>&1
sc config SysMain start= auto > nul 2>&1
sc config lfsvc start= demand > nul 2>&1
sc config CscService start= demand > nul 2>&1
sc config PhoneSvc start= demand > nul 2>&1
sc config WalletService start= demand > nul 2>&1
sc config TermService start= demand > nul 2>&1
sc config SessionEnv start= demand > nul 2>&1
sc config UmRdpService > nul 2>&1
sc config wuauserv start= demand > nul 2>&1
sc config UsoSvc start= delayed-auto > nul 2>&1
sc config BITS start= delayed-auto > nul 2>&1
sc config WaaSMedicSvc start= demand > nul 2>&1
sc config WinDefend start= auto > nul 2>&1
sc config wscsvc start= delayed-auto > nul 2>&1
sc config Sense start= demand > nul 2>&1
sc config WdNisSvc start= demand > nul 2>&1
sc config wmiApSrv start= demand > nul 2>&1
sc config XboxGipSvc start= demand > nul 2>&1
sc config xbgm start= demand > nul 2>&1
sc config XblAuthManager start= demand > nul 2>&1
sc config XblGameSave start= demand > nul 2>&1
sc config XboxNetApiSvc start= demand > nul 2>&1

:: Revert User Services via Registry
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WpnUserService" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BluetoothUserService" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CDPUserSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CaptureService" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ConsentUxUserSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PimIndexMaintenanceSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DevicePickerUserSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\OneSyncSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UserDataSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UnistoreSvc" /v Start /t REG_DWORD /d 2 /f > nul 2>&1

call :WRITE_LOG "Reverted Services Optimization to Default"
color 0A
echo     [SUCCESS] Services Reverted to Default!
timeout /t 3 >nul
goto SERVICES_OPTIMIZATION_MENU

:: ============================================================================
:: END OF SCRIPT
:: ============================================================================
goto :eof

:WRITE_LOG
if not exist "C:\TGO" mkdir "C:\TGO" >nul 2>&1
if not exist "C:\TGO\logs" mkdir "C:\TGO\logs" >nul 2>&1
echo [%date% %time:~0,8%] - %* >> "C:\TGO\logs\TGO_Log.txt"
goto :eof
