@echo off
"%~dp0IMPERATHEN.exe" --rendering-method forward_plus --rendering-driver vulkan %*
exit /b %ERRORLEVEL%
