echo off
:restorepoint
cls
echo. [R] Buat Restore Point  [E] Jika Hasilnya Buruk  [X] Exit && echo.
set /p input=:
if /i %input% == R goto r
if /i %input% == E goto e
if /i %input% == X goto x

) ELSE (
echo Invalid Input & goto MisspellRedirect

:MisspellRedirect
cls
echo Misspell Detected
timeout 3
goto RedirectMenu

:RedirectMenu
goto restorepoint

:r
cls
powershell -Command "Checkpoint-Computer -Description 'TGOpti Restore Point' -RestorePointType 'MODIFY_SETTINGS'" 

powershell -Command "& {Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Restore Point Berhasil Dibuat !', 'Tech Gameplay', 'Ok', [System.Windows.Forms.MessageBoxIcon]::Information);}"
pause
goto restorepoint

:e
cls
rstrui.exe
pause
goto restorepoint

:x
exit