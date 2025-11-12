echo off
cls
sc config SysMain start=disabled
sc stop SysMain
pause
cls
exit