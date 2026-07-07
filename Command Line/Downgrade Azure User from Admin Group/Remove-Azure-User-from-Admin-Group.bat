@echo off
setlocal

echo ============================================================
echo  Net Primates - AzureAD Local Group Adjustment
echo ============================================================
echo  This script will, for the AzureAD user you specify:
echo    1. ADD the user to the local "Users" group
echo    2. REMOVE the user from the local "Administrators" group
echo.
echo  Enter the username only (e.g. JohnDoe@domain), not the
echo  full "AzureAD\..." prefix - that will be added automatically.
echo ============================================================
echo.

set /p "AadUser=Enter AzureAD username: "

if "%AadUser%"=="" (
    echo.
    echo No username entered. Nothing was changed. Exiting.
    pause
    goto :selfdelete
)

echo.
echo Applying changes for AzureAD\%AadUser% ...
echo.

net localgroup users "AzureAD\%AadUser%" /add
net localgroup administrators "AzureAD\%AadUser%" /delete

echo.
echo ============================================================
echo  Done. Review the output above to confirm both commands
echo  completed without errors for AzureAD\%AadUser%.
echo ============================================================
echo.
pause

:selfdelete
(goto) 2>nul & del "%~f0"