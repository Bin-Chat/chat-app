@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   CHAT APP - DEPLOY LAMBDA FUNCTIONS
echo ========================================
echo.

REM ── Check AWS CLI ─────────────────────────────────────────────────────────
echo [1/5] Checking AWS CLI...
set "AWS_CMD=aws"
where aws >nul 2>&1
if errorlevel 1 (
    if exist "C:\Program Files\Amazon\AWSCLIV2\aws.exe" (
        set "AWS_CMD=C:\Program Files\Amazon\AWSCLIV2\aws.exe"
        echo [INFO] aws not found in PATH, using: !AWS_CMD!
    ) else (
        echo ERROR: AWS CLI is not installed or not found!
        echo.
        echo Install AWS CLI from:
        echo   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
        echo.
        echo Or via winget:
        echo   winget install Amazon.AWSCLI
        echo.
        pause
        exit /b 1
    )
)
"%AWS_CMD%" --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: AWS CLI command is not executable: %AWS_CMD%
    pause
    exit /b 1
)
echo [OK] AWS CLI is ready
"%AWS_CMD%" --version

REM ── Check AWS credentials ─────────────────────────────────────────────────
echo.
echo [2/5] Checking AWS credentials...
"%AWS_CMD%" sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo ERROR: AWS credentials not configured!
    echo Run: aws configure
    echo.
    pause
    exit /b 1
)
echo [OK] AWS credentials OK

set "AWS_ACCOUNT_ID="
"%AWS_CMD%" sts get-caller-identity --query Account --output text > "%TEMP%\aws_account.tmp" 2>nul
set /p AWS_ACCOUNT_ID=<"%TEMP%\aws_account.tmp"
del "%TEMP%\aws_account.tmp" >nul 2>&1
if "%AWS_ACCOUNT_ID%"=="" (
    echo WARNING: Could not detect AWS account ID automatically.
) else (
    echo [OK] AWS_ACCOUNT_ID = %AWS_ACCOUNT_ID%
)

REM ── Check required env vars ───────────────────────────────────────────────
echo.
echo [3/5] Checking required environment variables...
if "%AWS_S3_BUCKET%"=="" (
    echo WARNING: AWS_S3_BUCKET not set, using default: binchat-s3
    set AWS_S3_BUCKET=binchat-s3
)
if "%AWS_REGION%"=="" (
    echo WARNING: AWS_REGION not set, using default: ap-southeast-1
    set AWS_REGION=ap-southeast-1
)
if "%LAMBDA_ROLE_ARN%"=="" (
    "%AWS_CMD%" iam list-roles --query "Roles[?contains(AssumeRolePolicyDocument.Statement[].Principal.Service[], 'lambda.amazonaws.com')].Arn | [0]" --output text > "%TEMP%\aws_role.tmp" 2>nul
    set /p LAMBDA_ROLE_ARN=<"%TEMP%\aws_role.tmp"
    del "%TEMP%\aws_role.tmp" >nul 2>&1
    if /I "!LAMBDA_ROLE_ARN!"=="None" set "LAMBDA_ROLE_ARN="
    if not "!LAMBDA_ROLE_ARN!"=="" (
        echo WARNING: LAMBDA_ROLE_ARN not set, auto-detected: !LAMBDA_ROLE_ARN!
    )
)
if "%LAMBDA_ROLE_ARN%"=="" (
    if not "%AWS_ACCOUNT_ID%"=="" (
        set "LAMBDA_ROLE_ARN=arn:aws:iam::%AWS_ACCOUNT_ID%:role/binchat-lambda-execution-role"
        echo WARNING: LAMBDA_ROLE_ARN not set, using default: !LAMBDA_ROLE_ARN!
    )
)
echo [OK] AWS_S3_BUCKET = %AWS_S3_BUCKET%
echo [OK] AWS_REGION    = %AWS_REGION%
if not "%LAMBDA_ROLE_ARN%"=="" echo [OK] LAMBDA_ROLE_ARN = %LAMBDA_ROLE_ARN%



REM ── Set Lambda function names (override if different) ─────────────────────
if "%LAMBDA_IMAGE_PROCESSOR%"=="" set LAMBDA_IMAGE_PROCESSOR=image-processor
if "%LAMBDA_VIDEO_DISPATCHER%"=="" set LAMBDA_VIDEO_DISPATCHER=video-dispatcher
if "%LAMBDA_RUNTIME%"=="" set LAMBDA_RUNTIME=nodejs20.x
if "%LAMBDA_ARCH%"=="" set LAMBDA_ARCH=x86_64
if "%LAMBDA_IMAGE_PROCESSOR_HANDLER%"=="" set LAMBDA_IMAGE_PROCESSOR_HANDLER=index.handler
if "%LAMBDA_VIDEO_DISPATCHER_HANDLER%"=="" set LAMBDA_VIDEO_DISPATCHER_HANDLER=index.handler

set ROOT=%~dp0..
set LAMBDA_DIR=%ROOT%\infrastructure\lambda
set DIST_DIR=%ROOT%\infrastructure\lambda\dist

echo.
echo [4/5] Building Lambda packages...

REM ── Clean dist ───────────────────────────────────────────────────────────
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%"

REM ───────────────────────────────────────────────────────────────────────────
REM  image-processor
REM  - uses sharp which needs Linux binary → build in a clean temp dir
REM ───────────────────────────────────────────────────────────────────────────
echo.
echo Building image-processor...

set "IMG_BUILD_DIR=%DIST_DIR%\image-processor-build"
if exist "%IMG_BUILD_DIR%" rmdir /s /q "%IMG_BUILD_DIR%"
mkdir "%IMG_BUILD_DIR%"

REM Copy source files (exclude existing node_modules)
xcopy /E /I /Y /EXCLUDE:"%LAMBDA_DIR%\image-processor\node_modules" "%LAMBDA_DIR%\image-processor\*" "%IMG_BUILD_DIR%\" >nul 2>&1
REM xcopy does not support exclusion of folders well, so copy package.json + index.mjs manually
copy /Y "%LAMBDA_DIR%\image-processor\package.json" "%IMG_BUILD_DIR%\package.json" >nul
copy /Y "%LAMBDA_DIR%\image-processor\index.mjs" "%IMG_BUILD_DIR%\index.mjs" >nul

REM Clean install with optionalDependencies — installs @img/sharp-linux-x64 binary for Lambda
cd "%IMG_BUILD_DIR%"
call npm install --include=optional
if errorlevel 1 (
    echo ERROR: npm install failed for image-processor
    pause
    exit /b 1
)
REM Install Linux x64 sharp binary using npm platform flags (npm >= 8.11)
call npm install --cpu=x64 --os=linux sharp
if errorlevel 1 (
    echo ERROR: Could not install Linux sharp binary
    pause
    exit /b 1
)

REM Zip from clean build dir
powershell -Command "Compress-Archive -Path '%IMG_BUILD_DIR%\*' -DestinationPath '%DIST_DIR%\image-processor.zip' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create image-processor.zip
    pause
    exit /b 1
)
echo [OK] image-processor.zip created

REM ───────────────────────────────────────────────────────────────────────────
REM  video-dispatcher
REM  - uses ffmpeg via @ffmpeg-installer/ffmpeg
REM  - must install linux-x64 binary explicitly when building on Windows
REM ───────────────────────────────────────────────────────────────────────────
echo.
echo Building video-dispatcher...

set "VID_BUILD_DIR=%DIST_DIR%\video-dispatcher-build"
if exist "%VID_BUILD_DIR%" rmdir /s /q "%VID_BUILD_DIR%"
mkdir "%VID_BUILD_DIR%"

copy /Y "%LAMBDA_DIR%\video-dispatcher\package.json" "%VID_BUILD_DIR%\package.json" >nul
copy /Y "%LAMBDA_DIR%\video-dispatcher\index.mjs" "%VID_BUILD_DIR%\index.mjs" >nul

cd "%VID_BUILD_DIR%"
call npm install
if errorlevel 1 (
    echo ERROR: npm install failed for video-dispatcher
    pause
    exit /b 1
)
REM Download Linux x64 ffmpeg binary directly from npm registry (bypasses OS restriction on Windows)
set "FFMPEG_VERSION=4.1.0"
set "FFMPEG_TGZ=%TEMP%\ffmpeg-linux-x64.tgz"
echo [INFO] Downloading @ffmpeg-installer/linux-x64@%FFMPEG_VERSION% ...
"%AWS_CMD_CURL%" >nul 2>&1
curl -sL "https://registry.npmjs.org/@ffmpeg-installer/linux-x64/-/linux-x64-%FFMPEG_VERSION%.tgz" -o "%FFMPEG_TGZ%"
if errorlevel 1 (
    echo ERROR: Failed to download ffmpeg Linux binary
    pause
    exit /b 1
)
mkdir "%VID_BUILD_DIR%\node_modules\@ffmpeg-installer\linux-x64" >nul 2>&1
tar xzf "%FFMPEG_TGZ%" --strip-components=1 -C "%VID_BUILD_DIR%\node_modules\@ffmpeg-installer\linux-x64"
if errorlevel 1 (
    echo ERROR: Failed to extract ffmpeg binary
    pause
    exit /b 1
)
del "%FFMPEG_TGZ%" >nul 2>&1
echo [OK] Linux ffmpeg binary installed

REM Zip size may be large (ffmpeg binary ~35 MB) — use S3 upload path if needed
powershell -Command "Compress-Archive -Path '%VID_BUILD_DIR%\*' -DestinationPath '%DIST_DIR%\video-dispatcher.zip' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create video-dispatcher.zip
    pause
    exit /b 1
)
echo [OK] video-dispatcher.zip created

REM ── Create Lambda functions if missing ─────────────────────────────────────
echo.
echo [4.5/5] Ensuring Lambda functions exist...

"%AWS_CMD%" lambda get-function --function-name "%LAMBDA_IMAGE_PROCESSOR%" --region "%AWS_REGION%" >nul 2>&1
if errorlevel 1 (
    echo WARNING: %LAMBDA_IMAGE_PROCESSOR% not found. Creating function...
    if "%LAMBDA_ROLE_ARN%"=="" (
        echo ERROR: LAMBDA_ROLE_ARN is required to create missing Lambda functions.
        echo Set it with: set LAMBDA_ROLE_ARN=arn:aws:iam::935358944551:role/service-role/your-lambda-role
        pause
        exit /b 1
    )
    "%AWS_CMD%" lambda create-function ^
        --function-name "%LAMBDA_IMAGE_PROCESSOR%" ^
        --runtime "%LAMBDA_RUNTIME%" ^
        --handler "%LAMBDA_IMAGE_PROCESSOR_HANDLER%" ^
        --zip-file "fileb://%DIST_DIR%\image-processor.zip" ^
        --role "%LAMBDA_ROLE_ARN%" ^
        --architectures "%LAMBDA_ARCH%" ^
        --region "%AWS_REGION%"
    if errorlevel 1 (
        echo ERROR: Failed to create %LAMBDA_IMAGE_PROCESSOR%
        echo Check LAMBDA_ROLE_ARN and IAM permissions: lambda:CreateFunction, iam:PassRole
        pause
        exit /b 1
    )
    echo [OK] %LAMBDA_IMAGE_PROCESSOR% created
) else (
    echo [OK] %LAMBDA_IMAGE_PROCESSOR% already exists
)

"%AWS_CMD%" lambda get-function --function-name "%LAMBDA_VIDEO_DISPATCHER%" --region "%AWS_REGION%" >nul 2>&1
if errorlevel 1 (
    echo WARNING: %LAMBDA_VIDEO_DISPATCHER% not found. Creating function...
    if "%LAMBDA_ROLE_ARN%"=="" (
        echo ERROR: LAMBDA_ROLE_ARN is required to create missing Lambda functions.
        echo Set it with: set LAMBDA_ROLE_ARN=arn:aws:iam::935358944551:role/service-role/your-lambda-role
        pause
        exit /b 1
    )
    "%AWS_CMD%" lambda create-function ^
        --function-name "%LAMBDA_VIDEO_DISPATCHER%" ^
        --runtime "%LAMBDA_RUNTIME%" ^
        --handler "%LAMBDA_VIDEO_DISPATCHER_HANDLER%" ^
        --zip-file "fileb://%DIST_DIR%\video-dispatcher.zip" ^
        --role "%LAMBDA_ROLE_ARN%" ^
        --architectures "%LAMBDA_ARCH%" ^
        --region "%AWS_REGION%"
    if errorlevel 1 (
        echo ERROR: Failed to create %LAMBDA_VIDEO_DISPATCHER%
        echo Check LAMBDA_ROLE_ARN and IAM permissions: lambda:CreateFunction, iam:PassRole
        pause
        exit /b 1
    )
    echo [OK] %LAMBDA_VIDEO_DISPATCHER% created
) else (
    echo [OK] %LAMBDA_VIDEO_DISPATCHER% already exists
)

REM ── Deploy to AWS Lambda ──────────────────────────────────────────────────
echo.
echo [5/5] Deploying to AWS Lambda (region: %AWS_REGION%)...

echo.
echo Deploying %LAMBDA_IMAGE_PROCESSOR%...
"%AWS_CMD%" lambda update-function-code ^
    --function-name "%LAMBDA_IMAGE_PROCESSOR%" ^
    --zip-file "fileb://%DIST_DIR%\image-processor.zip" ^
    --region "%AWS_REGION%"
if errorlevel 1 (
    echo ERROR: Failed to deploy %LAMBDA_IMAGE_PROCESSOR%
    echo Check IAM permission: lambda:UpdateFunctionCode
    pause
    exit /b 1
)
REM Ensure correct timeout and memory for image processing
"%AWS_CMD%" lambda update-function-configuration ^
    --function-name "%LAMBDA_IMAGE_PROCESSOR%" ^
    --timeout 60 --memory-size 512 ^
    --region "%AWS_REGION%" >nul 2>&1
echo [OK] %LAMBDA_IMAGE_PROCESSOR% deployed (timeout=60s, memory=512MB)

echo.
echo Deploying %LAMBDA_VIDEO_DISPATCHER%...
REM video-dispatcher zip includes ffmpeg binary (~35 MB) — try direct upload first,
REM fall back to S3 if the file exceeds Lambda's 50 MB direct-upload limit.
for %%F in ("%DIST_DIR%\video-dispatcher.zip") do set VID_ZIP_SIZE=%%~zF
if !VID_ZIP_SIZE! GTR 52428800 (
    echo [INFO] video-dispatcher.zip is !VID_ZIP_SIZE! bytes, uploading via S3...
    "%AWS_CMD%" s3 cp "%DIST_DIR%\video-dispatcher.zip" "s3://%AWS_S3_BUCKET%/lambda-deploy/video-dispatcher.zip" --region "%AWS_REGION%"
    if errorlevel 1 (
        echo ERROR: Failed to upload video-dispatcher.zip to S3
        pause
        exit /b 1
    )
    "%AWS_CMD%" lambda update-function-code ^
        --function-name "%LAMBDA_VIDEO_DISPATCHER%" ^
        --s3-bucket "%AWS_S3_BUCKET%" ^
        --s3-key "lambda-deploy/video-dispatcher.zip" ^
        --region "%AWS_REGION%"
) else (
    "%AWS_CMD%" lambda update-function-code ^
        --function-name "%LAMBDA_VIDEO_DISPATCHER%" ^
        --zip-file "fileb://%DIST_DIR%\video-dispatcher.zip" ^
        --region "%AWS_REGION%"
)
if errorlevel 1 (
    echo ERROR: Failed to deploy %LAMBDA_VIDEO_DISPATCHER%
    echo Check IAM permission: lambda:UpdateFunctionCode
    pause
    exit /b 1
)
REM Ensure correct timeout and memory for ffmpeg video processing
"%AWS_CMD%" lambda update-function-configuration ^
    --function-name "%LAMBDA_VIDEO_DISPATCHER%" ^
    --timeout 300 --memory-size 1024 ^
    --region "%AWS_REGION%" >nul 2>&1
echo [OK] %LAMBDA_VIDEO_DISPATCHER% deployed (timeout=300s, memory=1024MB)

REM ── Done ─────────────────────────────────────────────────────────────────
echo.
echo ========================================
echo   DEPLOY COMPLETE
echo ========================================
echo   image-processor  -> %LAMBDA_IMAGE_PROCESSOR%
echo   video-dispatcher -> %LAMBDA_VIDEO_DISPATCHER%
echo   Region           -> %AWS_REGION%
echo ========================================
echo.
echo Zip files saved to: %DIST_DIR%
echo.
pause
