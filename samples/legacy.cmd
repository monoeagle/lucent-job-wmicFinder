@echo off
REM wmic bios get serialnumber
wmic csproduct get uuid
:: wmic path win32_service get name
