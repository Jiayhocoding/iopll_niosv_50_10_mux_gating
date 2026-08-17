@echo off
echo FPGA Configure...

set project_sof=golden_top.sof
set project_elf=nios_app.elf

REM ########################################################################
REM # Download sof file
REM ########################################################################
@ set QUARTUS_BIN=%QUARTUS_ROOTDIR%\bin
@ if not exist "%QUARTUS_BIN%" set QUARTUS_BIN=%QUARTUS_ROOTDIR%\bin64

%QUARTUS_BIN%\quartus_pgm.exe -m jtag -c 1 -o "p;%project_sof%@1"

REM ########################################################################
REM # Download elf file and open termianl
REM ########################################################################

%QUARTUS_ROOTDIR%\..\niosv\bin\niosv-shell.exe --run "niosv-download.exe %project_elf% -c 1 -r -g"
%QUARTUS_ROOTDIR%\..\niosv\bin\niosv-shell.exe --run "juart-terminal -c 1"


pause


