echo off
cls
del /s /f /q c:\windows\temp.
del /s /f /q C:\WINDOWS\Prefetch
del /s /f /q %temp%.
del /s /f /q %systemdrive%\*.tmp
del /s /f /q %systemdrive%\*._mp
del /s /f /q %systemdrive%\*.log
del /s /f /q %systemdrive%\*.gid
del /s /f /q %systemdrive%\*.chk
del /s /f /q %systemdrive%\*.old
del /s /f /q %systemdrive%\recycled\*.*
del /s /f /q %systemdrive%\$Recycle.Bin\*.*
del /s /f /q %windir%\*.bak
del /s /f /q %windir%\prefetch\*.*
del /s /f /q %LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db
del /s /f /q %LocalAppData%\Microsoft\Windows\Explorer\*.db
del /f /q %SystemRoot%\Logs\CBS\CBS.log
del /f /q %SystemRoot%\Logs\DISM\DISM.log
cls
net stop wuauserv
net stop UsoSvc
net stop bits
net stop dosvc
rd /s /q C:\Windows\SoftwareDistribution
md C:\Windows\SoftwareDistribution
cls
cd/
del *.log /a /s /q /f
cls
POWERSHELL "Optimize-Volume -DriveLetter C -ReTrim"
exit