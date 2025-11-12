echo off
cls
For /f "Delims=" %%k in ('Reg.exe Query HKLM\SYSTEM\CurrentControlSet\Enum /f "{4d36e967-e325-11ce-bfc1-08002be10318}" /d /s^|Find "HKEY"') do (
Reg.exe delete "%%k\Device Parameters\Disk" /v UserWriteCacheSetting /f 
Reg.exe add "%%k\Device Parameters\Disk" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f
)
pause
cls
fsutil behavior set memoryusage 2
fsutil behavior set disablelastaccess 1
fsutil behavior set disabledeletenotify 0
fsutil behavior set encryptpagingfile 0
fsutil behavior set mftzone 4
fsutil behavior set disable8dot3 1
pause
cls
exit