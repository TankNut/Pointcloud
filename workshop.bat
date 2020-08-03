set WORKSHOP_ID=2185917826

cd /d "%~dp0"
cd ..\..\..\bin\

gmad create -folder "%~dp0\" -out "%~dp0..\__TEMP.gma"
gmpublish update -addon "%~dp0..\__TEMP.gma" -id "%WORKSHOP_ID%"

cd /d "%~dp0"

del ..\__TEMP.gma

pause