@echo off
%1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit

chcp 65001 >nul
setlocal enabledelayedexpansion
title 端口进程终结工具
color 0A

:input_port
set /p "port=请输入需要终止的端口号（0-65535）："
if "%port%"=="" goto input_port
echo 正在扫描 %port% 端口...

set counter=0
for /f "tokens=2,5" %%a in ('netstat -ano ^| findstr /r /c:":%port% "') do (
  for /f "tokens=1,2 delims=:" %%i in ("%%a") do (
    if "%%j"=="%port%" (
      set pid=%%b
      taskkill /f /pid !pid! >nul 2>&1
      echo 已终止 PID:!pid! 的进程
      set /a counter+=1
    )
  )
)

if %counter%==0 (
  echo 端口 %port% 未被占用
) else (
  echo 共终止 %counter% 个占用进程
)
pause