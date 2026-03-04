@echo off
PowerShell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%~dp0setup-dev-env.ps1""' -Verb RunAs"
