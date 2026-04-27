# STM32 Debug Script (Universal)
# Usage:
#   .\start_debug.ps1 -ProjectDir "F:\path\to\project"
#   .\start_debug.ps1 -ProjectDir "F:\path" -UV4Path "C:\Keil\UV4\UV4.exe" -GDBPath "C:\...\arm-none-eabi-gdb.exe"
#
# Supports: GDB client, RTT Viewer, Serial Shell, VSCode debug.
# Tool paths are auto-detected; override with -UV4Path, -GDBPath, -GDBServerPath, -ProgrammerPath.

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,

    [switch]$SkipBuild,
    [switch]$GDBClient,
    [switch]$RTT,
    [switch]$Shell,
    [int]$BaudRate = 115200,

    # -------- 可选：工具路径覆盖 --------
    [string]$UV4Path,
    [string]$GDBPath,
    [string]$GDBServerPath,
    [string]$ProgrammerPath,
    [string]$CMakePath
)

$ErrorActionPreference = "Continue"

# ----------------------------------------
# 工具查找函数
# ----------------------------------------
function Find-KeilUV4 {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) { return $UserPath }
    $paths = @(
        "${env:ProgramFiles(x86)}\Keil\UV4\UV4.exe",
        "D:\keil5\UV4\UV4.exe",
        "C:\Keil\UV4\UV4.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p -PathType Leaf) { return $p }
    }
    try {
        $regPath = (Get-ItemProperty "HKLM:\SOFTWARE\Keil\Products\UV4" -ErrorAction SilentlyContinue).Path
        if ($regPath) {
            $full = Join-Path $regPath "UV4.exe"
            if (Test-Path $full -PathType Leaf) { return $full }
        }
    } catch { }
    return $null
}

function Find-GDB {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) { return $UserPath }
    $dir = Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\gnu-gdb-for-stm32" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($dir) {
        $gdb = Get-ChildItem $dir.FullName -Filter "arm-none-eabi-gdb.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($gdb) { return $gdb }
    }
    return $null
}

function Find-GDBServer {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) { return $UserPath }
    $dir = Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\stlink-gdbserver" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($dir) {
        $srv = Get-ChildItem $dir.FullName -Filter "ST-LINK_gdbserver.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($srv) { return $srv }
    }
    return $null
}

function Find-Programmer {
    param([string]$UserPath)
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) { return $UserPath }
    $dir = Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\programmer" -Directory -ErrorAction SilentlyContinue |
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
    if ($UserPath -and (Test-Path $UserPath -PathType Leaf)) { return $UserPath }
    $dir = Get-ChildItem "$env:LOCALAPPDATA\stm32cube\bundles\cmake" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($dir) {
        $cmake = Get-ChildItem $dir.FullName -Filter "cmake.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($cmake) { return $cmake }
    }
    return $null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STM32 Universal Debug" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------
# Step 1: Find Tools
# ----------------------------------------
Write-Host "[1/5] Finding tools..." -ForegroundColor Yellow

$gdb = Find-GDB -UserPath $GDBPath
if (-not $gdb) {
    Write-Host "ERROR: arm-none-eabi-gdb not found" -ForegroundColor Red
    Write-Host "  Hint: Set -GDBPath or install STM32CubeProgrammer bundle" -ForegroundColor Yellow
    exit 1
}
Write-Host "  GDB: $gdb" -ForegroundColor Green

$gdbServer = Find-GDBServer -UserPath $GDBServerPath
if (-not $gdbServer) {
    Write-Host "ERROR: ST-Link GDB Server not found" -ForegroundColor Red
    Write-Host "  Hint: Set -GDBServerPath or install STM32CubeProgrammer bundle" -ForegroundColor Yellow
    exit 1
}
Write-Host "  GDB Server: $gdbServer" -ForegroundColor Green

$programmerBin = $null
$programmerDir = Find-Programmer -UserPath $ProgrammerPath
if ($programmerDir) {
    $programmerBin = Split-Path $programmerDir -Parent
    Write-Host "  STM32CubeProgrammer: $programmerBin" -ForegroundColor Green
} else {
    Write-Host "  STM32CubeProgrammer: not found (set -ProgrammerPath)" -ForegroundColor Yellow
}

$cmake = Find-CMake -UserPath $CMakePath

# JLink RTT Client (optional)
$jlinkRtt = $null
$jlinkDirs = @("C:\Program Files\SEGGER\JLink", "$env:LOCALAPPDATA\stm32cube\bundles\jlink-gdbserver")
foreach ($dir in $jlinkDirs) {
    if (Test-Path $dir) {
        $jlinkRtt = Get-ChildItem $dir -Filter "JLinkRTTClient.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($jlinkRtt) { break }
    }
}

# ----------------------------------------
# Step 2: Build (unless skipped)
# ----------------------------------------
if (-not $SkipBuild -and -not $RTT -and -not $Shell) {
    Write-Host ""
    Write-Host "[2/5] Building project..." -ForegroundColor Yellow

    # 尝试检测项目类型
    $isKeil = Test-Path "$ProjectDir\Projects\MDK-ARM\*.uvprojx" -PathType Leaf
    $isCMake = Test-Path "$ProjectDir\CMakeLists.txt" -PathType Leaf

    if ($isKeil) {
        $uv4 = Find-KeilUV4 -UserPath $UV4Path
        if (-not $uv4) {
            Write-Host "ERROR: Keil UV4 not found" -ForegroundColor Red
            exit 1
        }
        $uvprojx = Get-ChildItem "$ProjectDir\Projects\MDK-ARM\*.uvprojx" | Select-Object -First 1 -ExpandProperty FullName
        $buildLog = Join-Path $ProjectDir "Output\build.log"
        Write-Host "  Project: $uvprojx" -ForegroundColor Gray
        $result = & $uv4 -j0 -o $buildLog -b $uvprojx 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Build complete" -ForegroundColor Green
    } elseif ($isCMake) {
        if (-not $cmake) {
            Write-Host "ERROR: CMake not found" -ForegroundColor Red
            exit 1
        }
        $buildDir = if (Test-Path "$ProjectDir\build\CMakeCache.txt") { "$ProjectDir\build" } else { "$ProjectDir\build" }
        if (-not (Test-Path "$ProjectDir\build\CMakeCache.txt")) {
            & $cmake -S $ProjectDir -B $buildDir -G "Ninja" 2>&1 | Out-Null
        }
        & $cmake --build $buildDir --config Debug 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Build failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Build complete" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Unknown project type" -ForegroundColor Red
        exit 1
    }
}

# ----------------------------------------
# Step 3: Find ELF
# ----------------------------------------
if (-not $RTT -and -not $Shell) {
    Write-Host ""
    Write-Host "[3/5] Finding ELF..." -ForegroundColor Yellow

    $isKeil = Test-Path "$ProjectDir\Projects\MDK-ARM\*.uvprojx" -PathType Leaf
    if ($isKeil) {
        $elf = Get-ChildItem "$ProjectDir\Output\*.axf" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    } else {
        $elf = Get-ChildItem $ProjectDir -Filter "*.elf" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "build" } |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $elf) {
        Write-Host "ERROR: No ELF found" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ELF: $elf" -ForegroundColor Green
}

# ----------------------------------------
# Step 4: Handle Debug Modes
# ----------------------------------------
Write-Host ""
Write-Host "[4/5] Starting debug mode..." -ForegroundColor Yellow

if ($RTT) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  RTT Viewer Mode" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($jlinkRtt) {
        Write-Host "Starting JLink RTT Client..." -ForegroundColor Green
        Write-Host "  RTT Client: $jlinkRtt" -ForegroundColor Gray
        Write-Host ""
        Start-Process -FilePath $jlinkRtt -NoNewWindow
        Start-Sleep -Seconds 2
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  RTT Viewer started!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Note: RTT requires:" -ForegroundColor Yellow
        Write-Host "  1. J-Link debugger connected" -ForegroundColor White
        Write-Host "  2. SEGGER_RTT_Init() called in firmware" -ForegroundColor White
        Write-Host "  3. RTT output configured in firmware" -ForegroundColor White
    } else {
        Write-Host "JLink RTT Client not found!" -ForegroundColor Red
        Write-Host "  C:\Program Files\SEGGER\JLink\JLinkRTTClient.exe" -ForegroundColor Gray
    }
    exit 0
}

if ($Shell) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Serial Shell Mode" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Baud Rate: $BaudRate" -ForegroundColor White
    Write-Host ""
    Write-Host "To connect manually:" -ForegroundColor Yellow
    Write-Host "  1. PuTTY: Serial connection to COMx, Speed $BaudRate" -ForegroundColor White
    Write-Host "  2. TeraTerm: Same settings" -ForegroundColor White
    Write-Host "  3. STM32CubeProgrammer: ST-LINK > Serial Port" -ForegroundColor White
    exit 0
}

# ----------------------------------------
# Step 5: Start Debug
# ----------------------------------------
Get-Process -Name "ST-LINK_gdbserver*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

$port = 61234
$serverArgs = if ($programmerBin) {
    @("-d", "-p", $port, "-cp", $programmerBin)
} else {
    @("-d", "-p", $port)
}

Write-Host ""
Write-Host "Starting GDB Server on port $port..." -ForegroundColor Gray
Start-Process -FilePath $gdbServer -ArgumentList $serverArgs -NoNewWindow -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$serverRunning = netstat -an 2>$null | Select-String "0.0.0.0:$port.*LISTENING"
if ($serverRunning) {
    Write-Host "  GDB Server running on port $port" -ForegroundColor Green
} else {
    Write-Host "  GDB Server started (background)" -ForegroundColor Green
}

if ($GDBClient) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  GDB Interactive Debug" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $gdbInit = @"
set confirm off
set pagination off
target remote localhost:$port
file "$elf"
break main
continue
"@
    $gdbInitPath = "$env:TEMP\stm32_debug_init.gdb"
    $gdbInit | Out-File -FilePath $gdbInitPath -Encoding ASCII

    Write-Host "GDB Commands:" -ForegroundColor White
    Write-Host "  target remote localhost:$port" -ForegroundColor Gray
    Write-Host "  file <elf>" -ForegroundColor Gray
    Write-Host "  break main" -ForegroundColor Gray
    Write-Host "  continue" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Yellow
    Write-Host ""
    & $gdb -x $gdbInitPath

} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Debug session ready" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Connect with GDB:" -ForegroundColor Yellow
    Write-Host "  arm-none-eabi-gdb.exe `"$elf`"" -ForegroundColor Gray
    Write-Host "  (gdb) target remote localhost:$port" -ForegroundColor Gray
    Write-Host "  (gdb) load" -ForegroundColor Gray
    Write-Host "  (gdb) break main" -ForegroundColor Gray
    Write-Host "  (gdb) continue" -ForegroundColor Gray
}

Write-Host ""
Write-Host "GDB Server still running on port $port" -ForegroundColor Gray
Write-Host "To kill: Stop-Process -Name 'ST-LINK_gdbserver*' -Force" -ForegroundColor Gray