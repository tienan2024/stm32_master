# STM32 Build & Flash Script (Universal)
# Usage:
#   .\build_flash.ps1 -ProjectDir "F:\path\to\stm32\project"
#   .\build_flash.ps1 -ProjectDir "F:\path\to\project" -UV4Path "C:\Keil\UV4\UV4.exe"
#
# Supports both CMake/Ninja and Keil MDK projects
# Tool paths are auto-detected from standard locations / registry.
# Override with -UV4Path, -ProgrammerPath, -CMakePath if needed.

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,

    [switch]$SkipBuild,         # Skip build, only flash
    [switch]$SkipSafetyCheck,  # Skip GPIO safety check (危险! 仅在确认安全后使用)

    # -------- 可选：工具路径覆盖 --------
    [string]$UV4Path,        # Keil MDK 路径，如 "C:\Keil\UV4\UV4.exe"
    [string]$ProgrammerPath, # STM32CubeProgrammer CLI，如 "C:\...\STM32_Programmer_CLI.exe"
    [string]$CMakePath       # CMake.exe 路径（通常不需要指定）
)

$ErrorActionPreference = "Continue"

# ----------------------------------------
# 工具查找函数（优先用参数，再自动检测）
# ----------------------------------------
function Find-KeilUV4 {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) {
        return $UserPath
    }
    # 自动检测
    $paths = @(
        "${env:ProgramFiles(x86)}\Keil\UV4\UV4.exe",
        "D:\keil5\UV4\UV4.exe",
        "C:\Keil\UV4\UV4.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p -PathType Leaf) { return $p }
    }
    # 注册表检测
    try {
        $regPath = (Get-ItemProperty "HKLM:\SOFTWARE\Keil\Products\UV4" -ErrorAction SilentlyContinue).Path
        if ($regPath) {
            $full = Join-Path $regPath "UV4.exe"
            if (Test-Path $full -PathType Leaf) { return $full }
        }
    } catch { }
    return $null
}

function Find-Programmer {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) {
        return $UserPath
    }
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    $dir = Get-ChildItem "$localAppData\stm32cube\bundles\programmer" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($dir) {
        $cli = Get-ChildItem $dir.FullName -Filter "STM32_Programmer_CLI.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($cli) { return $cli }
    }
    return $null
}

function Find-CMake {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) {
        return $UserPath
    }
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    $dir = Get-ChildItem "$localAppData\stm32cube\bundles\cmake" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($dir) {
        $cmake = Get-ChildItem $dir.FullName -Filter "cmake.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($cmake) { return $cmake }
    }
    return $null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STM32 Universal Build & Flash" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectDir" -ForegroundColor White

# ----------------------------------------
# Step 1: Detect project type
# ----------------------------------------
$isKeil = Test-Path "$ProjectDir\Projects\MDK-ARM\*.uvprojx" -PathType Leaf
$isCMake = Test-Path "$ProjectDir\CMakeLists.txt" -PathType Leaf

Write-Host ""
Write-Host "[1/5] Detecting project type..." -ForegroundColor Yellow
if ($isKeil) {
    Write-Host "  Project type: Keil MDK (UVPROJX)" -ForegroundColor Green
} elseif ($isCMake) {
    Write-Host "  Project type: CMake/Ninja" -ForegroundColor Green
} else {
    Write-Host "ERROR: Unknown project type (no .uvprojx or CMakeLists.txt found)" -ForegroundColor Red
    exit 1
}

# ----------------------------------------
# Step 2: Find tools
# ----------------------------------------
Write-Host ""
Write-Host "[2/5] Finding tools..." -ForegroundColor Yellow

$programmer = Find-Programmer -UserPath $ProgrammerPath
if (-not $programmer) {
    Write-Host "ERROR: STM32CubeProgrammer CLI not found" -ForegroundColor Red
    Write-Host "  Hint: Set -ProgrammerPath or install STM32CubeProgrammer" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Programmer: $programmer" -ForegroundColor Green

$uv4 = $null
if ($isKeil) {
    $uv4 = Find-KeilUV4 -UserPath $UV4Path
    if (-not $uv4) {
        Write-Host "ERROR: Keil UV4 not found" -ForegroundColor Red
        Write-Host "  Hint: Set -UV4Path or install Keil MDK" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  UV4: $uv4" -ForegroundColor Green
}

$cmake = $null
if ($isCMake) {
    $cmake = Find-CMake -UserPath $CMakePath
    if (-not $cmake) {
        Write-Host "ERROR: CMake not found" -ForegroundColor Red
        Write-Host "  Hint: Set -CMakePath or install STM32CubeProgammer bundle" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  CMake: $cmake" -ForegroundColor Green
}

# ----------------------------------------
# Step 3: Build
# ----------------------------------------
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[3/5] Building project..." -ForegroundColor Yellow

    if ($isKeil) {
        $uvprojx = Get-ChildItem "$ProjectDir\Projects\MDK-ARM\*.uvprojx" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if (-not $uvprojx) {
            Write-Host "ERROR: No .uvprojx file found" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Project: $uvprojx" -ForegroundColor Gray

        $buildLog = Join-Path $ProjectDir "Output\build.log"
        $buildResult = & $uv4 -j0 -o $buildLog -b $uvprojx 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed!" -ForegroundColor Red
            if (Test-Path $buildLog) {
                Get-Content $buildLog | Select-Object -Last 30
            }
            exit 1
        }

        if (Test-Path $buildLog) {
            $log = Get-Content $buildLog -Raw
            if ($log -match "(\d+) Error\(s\)") {
                $errors = $matches[1]
                if ($errors -gt 0) {
                    Write-Host "Build failed with $errors error(s)!" -ForegroundColor Red
                    Get-Content $buildLog | Select-Object -Last 20
                    exit 1
                }
            }
        }
        Write-Host "  Build complete (0 errors)" -ForegroundColor Green

        $elf = Get-ChildItem "$ProjectDir\Output\*.axf" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName

    } else {
        $buildDir = $null
        if (Test-Path "$ProjectDir\build\CMakeCache.txt") {
            $buildDir = "$ProjectDir\build"
        } elseif (Test-Path "$ProjectDir\build\Debug\CMakeCache.txt") {
            $buildDir = "$ProjectDir\build\Debug"
        } elseif (Test-Path "$ProjectDir\build\Release\CMakeCache.txt") {
            $buildDir = "$ProjectDir\build\Release"
        }

        if (-not $buildDir) {
            Write-Host "  No build directory found, configuring first..."
            & $cmake -S $ProjectDir -B "$ProjectDir\build" -G "Ninja" 2>&1 | Out-Null
            if (Test-Path "$ProjectDir\build\CMakeCache.txt") {
                $buildDir = "$ProjectDir\build"
            } else {
                Write-Host "ERROR: Could not configure CMake build" -ForegroundColor Red
                exit 1
            }
        }

        Write-Host "  Build directory: $buildDir" -ForegroundColor Gray
        $buildResult = & $cmake --build $buildDir --config Debug 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed!" -ForegroundColor Red
            Write-Host $buildResult
            exit 1
        }
        Write-Host "  Build complete" -ForegroundColor Green

        $elf = Get-ChildItem $ProjectDir -Filter "*.elf" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "build" } |
            Select-Object -First 1 -ExpandProperty FullName
    }
} else {
    Write-Host ""
    Write-Host "[3/5] Skipping build (using existing ELF)..." -ForegroundColor Yellow

    if ($isKeil) {
        $elf = Get-ChildItem "$ProjectDir\Output\*.axf" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    } else {
        $elf = Get-ChildItem $ProjectDir -Filter "*.elf" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "build" } |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

# ----------------------------------------
# Step 4: Flash
# ----------------------------------------
Write-Host ""
Write-Host "[4/5] Finding ELF file..." -ForegroundColor Yellow

if (-not $elf -or -not (Test-Path $elf)) {
    Write-Host "ERROR: ELF file not found: $elf" -ForegroundColor Red
    exit 1
}
Write-Host "  Found: $elf" -ForegroundColor Green

# ----------------------------------------
# Step 4.5: GPIO Safety Check
# ----------------------------------------
if (-not $SkipSafetyCheck) {
    Write-Host ""
    Write-Host "[4.5/6] Running GPIO Safety Check..." -ForegroundColor Yellow
    $safetyScript = Join-Path $PSScriptRoot "check_gpio_safety.ps1"

    if (Test-Path $safetyScript) {
        $safetyResult = & $safetyScript -ProjectDir $ProjectDir 2>&1
        $safeExitCode = $LASTEXITCODE
        $safetyResult | Out-Host

        if ($safeExitCode -ne 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Red
            Write-Host "  ⚠️  安全检查失败 - 存在严重错误!" -ForegroundColor Red
            Write-Host "  请修复上述问题后重试" -ForegroundColor Red
            Write-Host "  或使用 -SkipSafetyCheck 跳过检查 (危险!)" -ForegroundColor Gray
            Write-Host "========================================" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ⚠️  Safety check script not found, skipping..." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[4.5/6] Skipping GPIO Safety Check (⚠️ 危险!)..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[5/6] Flashing to device..." -ForegroundColor Yellow

Write-Host ""
Write-Host "  Device Info:" -ForegroundColor Cyan
$deviceInfo = & $programmer -c port=SWD 2>&1
$deviceInfo | Select-Object -First 20
Write-Host ""

$flashResult = & $programmer -c port=SWD --download $elf -v 2>&1
$flashResult

if ($LASTEXITCODE -eq 0) {
    $elfSize = (Get-Item $elf).Length
    $elfSizeKB = [math]::Round($elfSize / 1024, 2)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SUCCESS: Flash completed!" -ForegroundColor Green
    Write-Host "  Firmware: $elfSizeKB KB" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  FAILED: Flash failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}

# ----------------------------------------
# Step 6/6: Warning if safety check was skipped
# ----------------------------------------
if ($SkipSafetyCheck) {
    Write-Host ""
    Write-Host "⚠️  注意: GPIO 安全检查已被跳过!" -ForegroundColor Yellow
    Write-Host "   请确保引脚配置正确，避免硬件损坏" -ForegroundColor Yellow
}