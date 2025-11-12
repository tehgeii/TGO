echo off
:queuesize
cls
echo. [L] 22  [M] 18  [H] 13  [R] Default  [I] Info  [X] Exit && echo.
set /p input=:
if /i %input% == L goto l
if /i %input% == M goto m
if /i %input% == H goto h
if /i %input% == R goto r
if /i %input% == I goto i
if /i %input% == X goto x

) ELSE (
echo Invalid Input & goto MisspellRedirect

:MisspellRedirect
cls
echo Misspell Detected
timeout 3
goto RedirectMenu

:RedirectMenu
goto queuesize

:l
cls
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "34" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "34" /f
for /f "delims=" %%i in ('powershell -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    set "pnpid=%%i"
    setlocal enabledelayedexpansion
    set "pnpid=!pnpid:\=\\!"
    set "regpath=HKLM\SYSTEM\CurrentControlSet\Enum\!pnpid!\Device Parameters"
    reg add "!regpath!" /v "AllowIdleIrpInD3" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "D3ColdSupported" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "DeviceSelectiveSuspended" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnableSelectiveSuspend" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnhancedPowerManagementEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendOn" /t REG_DWORD /d "0" /f

)

reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "1" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "4" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f 
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f
reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d "31" /f
pause
goto queuesize

:m
cls
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "24" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "24" /f
for /f "delims=" %%i in ('powershell -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    set "pnpid=%%i"
    setlocal enabledelayedexpansion
    set "pnpid=!pnpid:\=\\!"
    set "regpath=HKLM\SYSTEM\CurrentControlSet\Enum\!pnpid!\Device Parameters"
    reg add "!regpath!" /v "AllowIdleIrpInD3" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "D3ColdSupported" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "DeviceSelectiveSuspended" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnableSelectiveSuspend" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnhancedPowerManagementEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendOn" /t REG_DWORD /d "0" /f

)

reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "1" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "4" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f 
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f
reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d "31" /f
pause
goto queuesize

:h
cls
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "19" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "19" /f
for /f "delims=" %%i in ('powershell -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    set "pnpid=%%i"
    setlocal enabledelayedexpansion
    set "pnpid=!pnpid:\=\\!"
    set "regpath=HKLM\SYSTEM\CurrentControlSet\Enum\!pnpid!\Device Parameters"
    reg add "!regpath!" /v "AllowIdleIrpInD3" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "D3ColdSupported" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "DeviceSelectiveSuspended" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnableSelectiveSuspend" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "EnhancedPowerManagementEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendEnabled" /t REG_DWORD /d "0" /f
    reg add "!regpath!" /v "SelectiveSuspendOn" /t REG_DWORD /d "0" /f

)

reg add "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /t REG_DWORD /d "31" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "1" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "4" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f 
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f
reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d "0" /f
reg add "HKCU\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d "31" /f
pause
goto queuesize

:r
cls
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "256" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "256" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f 
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "2" /f 
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-PnpDevice -Class USB | Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | ForEach-Object { $_.InstanceId }"') do (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "AllowIdleIrpInD3" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "D3ColdSupported" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "DeviceSelectiveSuspended" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "EnableSelectiveSuspend" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "EnhancedPowerManagementEnabled" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "SelectiveSuspendEnabled" /f
    reg delete "HKLM\SYSTEM\CurrentControlSet\Enum\%%i\Device Parameters" /v "SelectiveSuspendOn" /f
)

reg delete "HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters" /v "ThreadPriority" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v "ThreadPriority" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v "ThreadPriority" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "ThreadPriority" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v "DisableSelectiveSuspend" /t REG_DWORD /d "0" /f 
reg delete "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /f
reg delete "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /f
reg delete "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /f
reg delete "HKCU\Control Panel\Accessibility\MouseKeys" /v "Flags" /f
pause
goto queuesize

:i
cls
echo i3 atau ryzen 3 pilih L
echo i5 atau ryzen 5 pilih M
echo i7 dan i9 atau ryzen 7 dan ryzen 9 pilih H
echo atau kalau kalian bingung, bisa tulis di kolom komentar cpu anda
echo.
pause
goto queuesize

:x
exit