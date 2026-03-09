@echo off
TITLE VideoMaMa Setup Wizard
cd /d "%~dp0"
echo ===================================================
echo   VideoMaMa (AlphaHint Generator) - Auto-Installer
echo ===================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "PYTHON_EXE=%SCRIPT_DIR%.venv\Scripts\python.exe"
set "HF_EXE=%SCRIPT_DIR%.venv\Scripts\hf.exe"
set "UV_EXE="

:: Check that uv sync has been run (the .venv directory should exist)
if not exist ".venv" (
    echo [ERROR] Project environment not found.
    echo Please run Install_CorridorKey_Windows.bat first!
    pause
    exit /b 1
)

if not exist "%PYTHON_EXE%" (
    echo [ERROR] Local Python executable not found:
    echo   "%PYTHON_EXE%"
    echo Please run Install_CorridorKey_Windows.bat first!
    pause
    exit /b 1
)

if not exist "%HF_EXE%" (
    call :resolve_uv
    if not defined UV_EXE (
        echo [ERROR] Could not find huggingface CLI in the local venv or via uv.
        echo.
        echo Tried:
        echo   - "%HF_EXE%"
        echo   - uv on PATH
        echo   - %%USERPROFILE%%\.local\bin\uv.exe
        echo   - %%USERPROFILE%%\.cargo\bin\uv.exe
        echo.
        echo Re-run Install_CorridorKey_Windows.bat, or open a new terminal after installing uv.
        pause
        exit /b 1
    )
)

set "VIDEOMAMA_DIR=VideoMaMaInferenceModule\checkpoints\VideoMaMa"
set "SVD_DIR=VideoMaMaInferenceModule\checkpoints\stable-video-diffusion-img2vid-xt"
set "SVD_FEATURE_EXTRACTOR=%SVD_DIR%\feature_extractor\preprocessor_config.json"
set "SVD_IMAGE_ENCODER=%SVD_DIR%\image_encoder\config.json"
set "SVD_VAE=%SVD_DIR%\vae\config.json"
set "SVD_INDEX=%SVD_DIR%\model_index.json"

:: 1. Ensure Hugging Face login
echo [1/3] Checking Hugging Face login...
call :run_hf auth whoami >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo Hugging Face login is required to download VideoMaMa checkpoints.
    echo You will need a token from:
    echo   https://huggingface.co/settings/tokens
    echo.
    choice /C YN /N /M "Open the Hugging Face tokens page in your browser? [Y/N]: "
    if errorlevel 2 (
        echo Skipping browser launch.
    ) else (
        start "" "https://huggingface.co/settings/tokens"
    )
    echo.
    echo Starting 'hf auth login'...
    call :run_hf auth login
    call :run_hf auth whoami >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Hugging Face login failed.
        pause
        exit /b 1
    )
)

:: 2. Download fine-tuned VideoMaMa weights
echo.
echo [2/3] Downloading VideoMaMa Model Weights...
if not exist "VideoMaMaInferenceModule\checkpoints" mkdir "VideoMaMaInferenceModule\checkpoints"
if not exist "%VIDEOMAMA_DIR%" mkdir "%VIDEOMAMA_DIR%"

echo Downloading VideoMaMa weights from HuggingFace...
call :run_hf download SammyLim/VideoMaMa --local-dir "%VIDEOMAMA_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download VideoMaMa weights.
    pause
    exit /b 1
)

:: 3. Download Stable Video Diffusion base model pieces into the exact path VideoMaMa expects
echo.
echo [3/3] Downloading Stable Video Diffusion base assets...
if not exist "%SVD_DIR%" mkdir "%SVD_DIR%"

set "SVD_READY=1"
if not exist "%SVD_FEATURE_EXTRACTOR%" set "SVD_READY=0"
if not exist "%SVD_IMAGE_ENCODER%" set "SVD_READY=0"
if not exist "%SVD_VAE%" set "SVD_READY=0"
if not exist "%SVD_INDEX%" set "SVD_READY=0"

if "%SVD_READY%"=="1" (
    echo Stable Video Diffusion base assets already exist!
) else (
    echo.
    echo The Stable Video Diffusion base model is gated on Hugging Face.
    echo You must accept the access request / license in the browser before download.
    echo Model page:
    echo   https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt
    echo.
    choice /C YN /N /M "Open the Stable Video Diffusion model page now? [Y/N]: "
    if errorlevel 2 (
        echo Skipping browser launch.
    ) else (
        start "" "https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt"
    )
    echo.
    echo In the browser, click the access / license acceptance button, then return here.
    pause
    echo.
    echo Downloading feature_extractor, image_encoder, vae, and model_index.json...
    "%PYTHON_EXE%" "%SCRIPT_DIR%VideoMaMaInferenceModule\download_svd_assets.py" --local-dir "%SVD_DIR%"
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to download Stable Video Diffusion base assets.
        echo.
        echo You likely need to accept the license first at:
        echo   https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt
        echo.
        echo After accepting, run this script again.
        pause
        exit /b 1
    )
)

if not exist "%SVD_FEATURE_EXTRACTOR%" (
    echo [ERROR] Missing Stable Video Diffusion file:
    echo   %SVD_FEATURE_EXTRACTOR%
    echo.
    echo The gated base model was not downloaded successfully.
    echo Accept the license at:
    echo   https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt
    echo Then re-run this installer.
    pause
    exit /b 1
)

if not exist "%SVD_IMAGE_ENCODER%" (
    echo [ERROR] Missing Stable Video Diffusion file:
    echo   %SVD_IMAGE_ENCODER%
    echo.
    echo Re-run this installer after accepting the model license.
    pause
    exit /b 1
)

if not exist "%SVD_VAE%" (
    echo [ERROR] Missing Stable Video Diffusion file:
    echo   %SVD_VAE%
    echo.
    echo Re-run this installer after accepting the model license.
    pause
    exit /b 1
)

if not exist "%SVD_INDEX%" (
    echo [ERROR] Missing Stable Video Diffusion file:
    echo   %SVD_INDEX%
    echo.
    echo Re-run this installer after accepting the model license.
    pause
    exit /b 1
)

echo.
echo ===================================================
echo   VideoMaMa Setup Complete!
echo ===================================================
pause
exit /b

:resolve_uv
where uv >nul 2>&1
if %errorlevel% equ 0 (
    set "UV_EXE=uv"
    goto :eof
)

if exist "%USERPROFILE%\.local\bin\uv.exe" (
    set "UV_EXE=%USERPROFILE%\.local\bin\uv.exe"
    goto :eof
)

if exist "%USERPROFILE%\.cargo\bin\uv.exe" (
    set "UV_EXE=%USERPROFILE%\.cargo\bin\uv.exe"
    goto :eof
)

goto :eof

:run_hf
if exist "%HF_EXE%" (
    "%HF_EXE%" %*
    exit /b %errorlevel%
)

if defined UV_EXE (
    "%UV_EXE%" run hf %*
    exit /b %errorlevel%
)

exit /b 1
