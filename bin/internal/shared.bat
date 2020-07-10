@ECHO on
REM Copyright 2014 The Flutter Authors. All rights reserved.
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file.

REM ---------------------------------- NOTE ----------------------------------
REM
REM Please keep the logic in this file consistent with the logic in the
REM `shared.sh` script in the same directory to ensure that Flutter & Dart continue to
REM work across all platforms!
REM
REM --------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION

SET flutter_tools_dir=%FLUTTER_ROOT%\packages\flutter_tools
SET cache_dir=%FLUTTER_ROOT%\bin\cache
SET snapshot_path=%cache_dir%\flutter_tools.snapshot
SET stamp_path=%cache_dir%\flutter_tools.stamp
SET script_path=%flutter_tools_dir%\bin\flutter_tools.dart
SET dart_sdk_path=%cache_dir%\dart-sdk
SET engine_stamp=%cache_dir%\engine-dart-sdk.stamp
SET engine_version_path=%FLUTTER_ROOT%\bin\internal\engine.version
SET pub_cache_path=%FLUTTER_ROOT%\.pub-cache

SET dart=%dart_sdk_path%\bin\dart.exe
SET pub=%dart_sdk_path%\bin\pub.bat

REM Detect which PowerShell executable is available on the Host
REM PowerShell version <= 5: PowerShell.exe
REM PowerShell version >= 6: pwsh.exe
WHERE /Q pwsh.exe && (
    SET powershell_executable=pwsh.exe
) || WHERE /Q PowerShell.exe && (
    SET powershell_executable=PowerShell.exe
) || (
    ECHO Error: PowerShell executable not found.
    ECHO        Either pwsh.exe or PowerShell.exe must be in your PATH.
    EXIT /B 1
)

REM Ensure that bin/cache exists.
IF NOT EXIST "%cache_dir%" MKDIR "%cache_dir%"

REM If the cache still doesn't exist, fail with an error that we probably don't have permissions.
IF NOT EXIST "%cache_dir%" (
  ECHO Error: Unable to create cache directory at
  ECHO            %cache_dir%
  ECHO.
  ECHO        This may be because flutter doesn't have write permissions for
  ECHO        this path. Try moving the flutter directory to a writable location,
  ECHO        such as within your home directory.
  EXIT /B 1
)

:acquire_lock
2>NUL (
  REM "3" is now stderr because of "2>NUL".
  CALL :subroutine %* 2>&3 9> "%cache_dir%\flutter.bat.lock" || GOTO acquire_lock
)
GOTO :after_subroutine

:subroutine
  PUSHD "%flutter_root%"
  FOR /f %%r IN ('git rev-parse HEAD') DO SET revision=%%r
  POPD

  REM The following IF conditions are all linked with a logical OR. However,
  REM there is no OR operator in batch and a GOTO construct is used as replacement.

  IF NOT EXIST "%engine_stamp%" GOTO do_sdk_update_and_snapshot
  SET /P dart_required_version=<"%engine_version_path%"
  SET /P dart_installed_version=<"%engine_stamp%"
  IF !dart_required_version! NEQ !dart_installed_version! GOTO do_sdk_update_and_snapshot
  IF NOT EXIST "%snapshot_path%" GOTO do_snapshot
  IF NOT EXIST "%stamp_path%" GOTO do_snapshot
  SET /P stamp_value=<"%stamp_path%"
  IF !stamp_value! NEQ !revision! GOTO do_snapshot
  SET pubspec_yaml_path=%flutter_tools_dir%\pubspec.yaml
  SET pubspec_lock_path=%flutter_tools_dir%\pubspec.lock
  FOR /F %%i IN ('DIR /B /O:D "%pubspec_yaml_path%" "%pubspec_lock_path%"') DO SET newer_file=%%i
  FOR %%i IN (%pubspec_yaml_path%) DO SET pubspec_yaml_timestamp=%%~ti
  FOR %%i IN (%pubspec_lock_path%) DO SET pubspec_lock_timestamp=%%~ti
  IF "%pubspec_yaml_timestamp%" == "%pubspec_lock_timestamp%" SET newer_file=""
  IF "%newer_file%" EQU "pubspec.yaml" GOTO do_snapshot

  REM Everything is up-to-date - exit subroutine
  EXIT /B

  :do_sdk_update_and_snapshot
    ECHO Checking Dart SDK version...
    ECHO zzz1
    SET update_dart_bin=%FLUTTER_ROOT%/bin/internal/update_dart_sdk.ps1
    ECHO zzz2
    REM Escape apostrophes from the executable path
    SET "update_dart_bin=!update_dart_bin:'=''!"
    ECHO zzz3
    %powershell_executable% Set-PSDebug -Trace 2
    ECHO "zzz4 %powershell_executable% %update_dart_bin%"
    %powershell_executable% -ExecutionPolicy Bypass -Command "Unblock-File -Path '%update_dart_bin%'; & '%update_dart_bin%'" 4>&1
    ECHO zzz5
    IF "%ERRORLEVEL%" NEQ "0" (
      ECHO Error: Unable to update Dart SDK. Retrying...
      timeout /t 5 /nobreak
      GOTO :do_sdk_update_and_snapshot
    )

  :do_snapshot
    IF EXIST "%FLUTTER_ROOT%\version" DEL "%FLUTTER_ROOT%\version"
    ECHO: > "%cache_dir%\.dartignore"
    ECHO Building flutter tool...
    PUSHD "%flutter_tools_dir%"

    REM Makes changes to PUB_ENVIRONMENT only visible to commands within SETLOCAL/ENDLOCAL
    SETLOCAL
      SET VERBOSITY=--verbosity=error
      IF "%CI%" == "true" GOTO on_bot
      IF "%BOT%" == "true" GOTO on_bot
      IF "%CONTINUOUS_INTEGRATION%" == "true" GOTO on_bot
      IF "%CHROME_HEADLESS%" == "1" GOTO on_bot
      GOTO not_on_bot
      :on_bot
        SET PUB_ENVIRONMENT=%PUB_ENVIRONMENT%:flutter_bot
        SET VERBOSITY=--verbosity=normal
      :not_on_bot
      SET PUB_ENVIRONMENT=%PUB_ENVIRONMENT%:flutter_install
      IF "%PUB_CACHE%" == "" (
        IF EXIST "%pub_cache_path%" SET PUB_CACHE=%pub_cache_path%
      )

      SET /A total_tries=10
      SET /A remaining_tries=%total_tries%-1
      :retry_pub_upgrade
        ECHO Running pub upgrade...
        CALL "%pub%" upgrade "%VERBOSITY%" --no-precompile
        IF "%ERRORLEVEL%" EQU "0" goto :upgrade_succeeded
        ECHO Error (%ERRORLEVEL%): Unable to 'pub upgrade' flutter tool. Retrying in five seconds... (%remaining_tries% tries left)
        timeout /t 5 /nobreak 2>NUL
        SET /A remaining_tries-=1
        IF "%remaining_tries%" EQU "0" GOTO upgrade_retries_exhausted
        GOTO :retry_pub_upgrade
      :upgrade_retries_exhausted
        SET exit_code=%ERRORLEVEL%
        ECHO Error: 'pub upgrade' still failing after %total_tries% tries, giving up.
        GOTO final_exit
      :upgrade_succeeded
    ENDLOCAL

    POPD

    IF "%FLUTTER_TOOL_ARGS%" == "" (
      "%dart%" --snapshot="%snapshot_path%" --packages="%flutter_tools_dir%\.packages" --no-enable-mirrors "%script_path%"
    ) else (
      "%dart%" "%FLUTTER_TOOL_ARGS%" --snapshot="%snapshot_path%" --packages="%flutter_tools_dir%\.packages" "%script_path%"
    )
    IF "%ERRORLEVEL%" NEQ "0" (
      ECHO Error: Unable to create dart snapshot for flutter tool.
      SET exit_code=%ERRORLEVEL%
      GOTO :final_exit
    )
    >"%stamp_path%" ECHO %revision%

  REM Exit Subroutine
  EXIT /B

:after_subroutine
