@echo off
echo Checking USB Debug Logs...
echo.
adb logcat -c
adb logcat | findstr USB_DEBUG
