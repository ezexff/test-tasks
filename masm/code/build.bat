@echo off

SET BuildPath=..\build

IF NOT EXIST %BuildPath% mkdir %BuildPath%
pushd %BuildPath%

ml64 ..\code\task6.asm /Zi /link /entry:main /subsystem:console
REM ml64 ..\code\task7.asm /Zi /link /entry:main /subsystem:windows 
REM cl ..\code\main.cpp /Zi /link /subsystem:windows user32.lib kernel32.lib comdlg32.lib
popd