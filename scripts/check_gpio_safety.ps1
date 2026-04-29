# STM32 GPIO 引脚与外设模块安全检查
# 检测可能导致硬件损坏的引脚配置和外设连接问题
#
# 使用方法:
#   .\scripts\check_gpio_safety.ps1 -ProjectDir "F:\path\to\project"
#   .\scripts\check_gpio_safety.ps1 -ProjectDir "F:\path\to\project" -Detailed
#
# 检测的危险模式:
#   - 引脚同时配置为输入和输出 (冲突)
#   - 同一引脚分配了冲突的复用功能
#   - 浮空输入 (无上拉/下拉)
#   - 外置模块引脚冲突 (I2C, SPI, UART, PWM, ADC)
#   - 电压等级不匹配 (3.3V vs 5V 模块)
#   - 电源引脚过载

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,

    [switch]$Detailed   # 显示详细分析
)

$ErrorActionPreference = "Continue"

$CriticalErrors = @()
$Warnings = @()
$InfoMessages = @()

function Get-CSourceFiles {
    param([string]$dir, [string]$exclude)
    $files = @()
    Get-ChildItem $dir -Recurse -Include "*.c","*.h" -File | ForEach-Object {
        if ($_.FullName -notmatch $exclude) {
            $files += $_.FullName
        }
    }
    return $files
}

function Test-PinConflict {
    param([string]$content, [string]$file)

    $pinConfigs = @{}

    # 查找所有 GPIO_Init 结构初始化
    $pinMatches = [regex]::Matches($content, '\.Pin\s*=\s*GPIO_PIN_(\d+)')
    foreach ($pm in $pinMatches) {
        $pinNum = $pm.Groups[1].Value
        if (-not $pinConfigs.ContainsKey($pinNum)) {
            $pinConfigs[$pinNum] = @()
        }
    }

    # 查找 .Mode = GPIO_MODE_xxx
    $modeMatches = [regex]::Matches($content, '\.Mode\s*=\s*(GPIO_MODE_[A-Z_]+)')
    foreach ($mm in $modeMatches) {
        $modeVal = $mm.Groups[1].Value
        foreach ($key in @($pinConfigs.Keys)) {
            $pinConfigs[$key] += $modeVal
        }
    }

    foreach ($pin in $pinConfigs.Keys) {
        $modes = $pinConfigs[$pin] | Select-Object -Unique
        $hasInput = ($modes | Where-Object { $_ -match "INPUT|IT_" }).Count -gt 0
        $hasOutput = ($modes | Where-Object { $_ -match "OUTPUT" }).Count -gt 0

        if ($hasInput -and $hasOutput) {
            $script:CriticalErrors += "[$file] 引脚 GPIO_PIN_$pin 同时配置为输入和输出 - 冲突风险!"
        }
    }

    foreach ($pin in $pinConfigs.Keys) {
        $modes = $pinConfigs[$pin] | Select-Object -Unique
        $isInput = ($modes | Where-Object { $_ -match "INPUT|IT_" }).Count -gt 0
        $hasPull = ($modes | Where-Object { $_ -match "PULLUP|PULLDOWN" }).Count -gt 0

        if ($isInput -and -not $hasPull) {
            $script:Warnings += "[$file] 引脚 GPIO_PIN_$pin 配置为输入但无上拉/下拉 - 可能产生噪声干扰"
        }
    }
}

function Test-ClockConfiguration {
    param([string]$content, [string]$file)

    $clockCalls = [regex]::Matches($content, '__HAL_RCC_([A-Z]+)_CLK_ENABLE\(\)')
    $clockPorts = $clockCalls | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

    $gpioInits = [regex]::Matches($content, 'HAL_GPIO_Init\s*\(\s*(GPIO[A-Z])\s*,')

    foreach ($init in $gpioInits) {
        $port = $init.Groups[1].Value
        if ($clockPorts -notcontains $port) {
            $script:Warnings += "[$file] GPIO $port 已使用但时钟可能未使能 - 请检查 __HAL_RCC_${port}_CLK_ENABLE()"
        }
    }
}

function Test-AlternateFunctionConflict {
    param([string]$content, [string]$file)

    $afPinUsage = @{}
    $afMatches = [regex]::Matches($content, 'GPIO_AF_(\d+)_([A-Z]+)')

    foreach ($af in $afMatches) {
        $afNum = $af.Groups[1].Value
        $func = $af.Groups[2].Value
        $key = "$afNum-$func"
        if (-not $afPinUsage.ContainsKey($key)) {
            $afPinUsage[$key] = 0
        }
        $afPinUsage[$key]++
    }

    foreach ($key in $afPinUsage.Keys) {
        if ($afPinUsage[$key] -gt 1) {
            $script:Warnings += "[$file] 复用功能 $key 被多次分配 - 可能存在冲突"
        }
    }
}

function Test-ExternalModules {
    param([string]$content, [string]$file)

    # ===== I2C 外置模块 =====
    $i2cPatterns = @(
        "BMP280|BME280|BMP180",
        "MPU6050|MPU9250|MPU6500",
        "OLED|ssd1306|ssd1331",
        "AHT10|AHT20|DHT22",
        "ADS1115|ADS1015",
        "PCF8574|PCF8591",
        "LIS3DH|LIS3DSH",
        "MPU9250|MPU6515"
    )

    foreach ($pattern in $i2cPatterns) {
        if ($content -match $pattern) {
            $script:InfoMessages += "[$file] 检测到外置 I2C 模块: $pattern"

            # 检查 I2C 引脚是否配置为 GPIO 输出
            $i2cPins = [regex]::Matches($content, '(I2C|SCL|SDA).*GPIO_PIN_(\d+)')
            foreach ($pin in $i2cPins) {
                if ($content -match "GPIO_MODE_OUTPUT") {
                    $script:CriticalErrors += "[$file] I2C 引脚 GPIO_PIN_$($pin.Groups[2].Value) 配置为输出 - 会损坏 I2C 设备!"
                }
            }

            # 检查 I2C 引脚是否有上拉电阻
            if ($content -match "I2C.*PULLUP" -and $content -notmatch "PULLUP") {
                $script:Warnings += "[$file] I2C 引脚可能缺少上拉电阻 - 总线可能无法工作"
            }
        }
    }

    # ===== SPI 外置模块 =====
    $spiPatterns = @(
        "SDIO|SD_CARD",
        "W25Q|Flash|SPIFlash",
        "ST7789|ILI9341|ILI9488",
        "SX1278|SX1262",
        "nRF24L01|RF24",
        "MAX7219|MAX7221",
        "AD7193|AD7195"
    )

    foreach ($pattern in $spiPatterns) {
        if ($content -match $pattern) {
            $script:InfoMessages += "[$file] 检测到外置 SPI 模块: $pattern"

            # 检查 SPI 引脚配置是否正确
            $spiPins = [regex]::Matches($content, '(MOSI|MISO|SCK|NSS|CS).*GPIO_PIN_(\d+)')
            foreach ($pin in $spiPins) {
                $pinNum = $pin.Groups[2].Value
                if ($content -match "GPIO_MODE_INPUT" -and $content -match "MOSI") {
                    $script:Warnings += "[$file] SPI MOSI 引脚 GPIO_PIN_$pinNum 配置为输入 - 应配置为复用功能"
                }
            }

            # 检查片选引脚冲突
            $csPins = [regex]::Matches($content, 'GPIO_PIN_(\d+).*CS|.*CS.*GPIO_PIN_(\d+)')
            if ($csPins.Count -gt 10) {
                $script:Warnings += "[$file] 检测到多个 SPI CS 引脚 - 请确认没有引脚共享"
            }
        }
    }

    # ===== UART 外置模块 =====
    $uartPatterns = @(
        "GPS|NEO|M8N",
        "HC-05|HC-06|Bluetooth",
        "ESP8266|ESP32",
        "LoRa|SX1278|SX1262",
        "SIM800|SIM7600|SIM900"
    )

    foreach ($pattern in $uartPatterns) {
        if ($content -match $pattern) {
            $script:InfoMessages += "[$file] 检测到外置 UART 模块: $pattern"

            # 检查 UART TX 不要配置为输入
            $uartPins = [regex]::Matches($content, '(UART|TX|RX).*GPIO_PIN_(\d+)')
            foreach ($pin in $uartPins) {
                if ($content -match "GPIO_MODE_INPUT") {
                    $script:CriticalErrors += "[$file] UART 引脚 GPIO_PIN_$($pin.Groups[2].Value) 配置为输入 - TX 应为输出!"
                }
            }
        }
    }

    # ===== PWM/电机驱动 =====
    $motorPatterns = @(
        "L298N|L293D",
        "TB6612|MD30",
        "DRV8833|DRV8825",
        "PCA9685",
        "Servo|PWM.*Motor",
        "Stepper"
    )

    foreach ($pattern in $motorPatterns) {
        if ($content -match $pattern) {
            $script:InfoMessages += "[$file] 检测到电机驱动模块: $pattern"
            $script:Warnings += "[$file] 确保 PWM 引脚未过载 - 电机驱动可能抽取大电流"
        }
    }

    # ===== 电源相关检查 =====
    $powerPatterns = @(
        "VCC.*GPIO|GPIO.*VCC",
        "3V3.*GPIO|5V.*GPIO",
        "POWER.*OUTPUT"
    )

    foreach ($pattern in $powerPatterns) {
        if ($content -match $pattern) {
            $script:Warnings += "[$file] 电源引脚可能被配置为 GPIO - 短路风险!"
        }
    }

    # ===== ADC 外置传感器 =====
    $adcPatterns = @(
        "Joystick|Potentiometer",
        "Current.*Sensor|ACS712",
        "Voltage.*Sensor",
        "Weight.*Sensor|Load.*Cell"
    )

    foreach ($pattern in $adcPatterns) {
        if ($content -match $pattern) {
            $script:InfoMessages += "[$file] 检测到模拟传感器: $pattern"

            # 检查 ADC 引脚不要配置为输出
            $adcPins = [regex]::Matches($content, '(ADC|PA[0-9]|PC[0-9]).*GPIO_PIN_(\d+)')
            foreach ($pin in $adcPins) {
                if ($content -match "GPIO_MODE_OUTPUT") {
                    $script:CriticalErrors += "[$file] ADC 引脚 GPIO_PIN_$($pin.Groups[2].Value) 配置为输出 - 会损坏传感器!"
                }
            }

            # 检查电压等级不匹配 (3.3V MCU vs 5V 传感器)
            if ($content -match "5V.*Sensor|5V.*ADC") {
                $script:Warnings += "[$file] 检测到 5V 传感器 - 请确认 ADC 引脚可承受 5V 或使用分压电路!"
            }
        }
    }
}

function Test-PowerOverload {
    param([string]$content, [string]$file)

    # 查找用作大电流输出的引脚 (LED, 蜂鸣器等)
    if ($content -match "LED|BUZZER|POWER.*OUT") {
        $script:Warnings += "[$file] 检测到电流吸收 GPIO 引脚 - 请确认有限流电阻"
    }

    # 检查短路保护
    if ($content -match "short.*circuit|overcurrent|OCP|OVP") {
        $script:InfoMessages += "[$file] 设计中包含短路保护电路"
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STM32 GPIO 与外设模块安全检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "扫描目录: $ProjectDir" -ForegroundColor White
Write-Host ""

$files = Get-CSourceFiles -dir $ProjectDir -exclude "Drivers/HAL|Drivers/CMSIS|\.git"

Write-Host "[1/4] 正在分析源文件..." -ForegroundColor Yellow

$allErrors = @()
$allWarnings = @()
$allInfo = @()

foreach ($file in $files) {
    if ($Detailed) {
        Write-Host "  检查中: $file" -ForegroundColor Gray
    }

    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue

    Test-PinConflict -content $content -file $file
    Test-ClockConfiguration -content $content -file $file
    Test-AlternateFunctionConflict -content $content -file $file
    Test-ExternalModules -content $content -file $file
    Test-PowerOverload -content $content -file $file
}

$allErrors = $CriticalErrors
$allWarnings = $Warnings
$allInfo = $InfoMessages

Write-Host "[2/4] 外置模块检测完成..." -ForegroundColor Yellow
Write-Host "[3/4] 生成报告..." -ForegroundColor Yellow

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安全报告" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($allInfo.Count -gt 0) {
    Write-Host ""
    Write-Host "📦 检测到外置模块 ($($allInfo.Count))" -ForegroundColor Blue
    foreach ($info in $allInfo) {
        Write-Host "   $info" -ForegroundColor Blue
    }
}

if ($allErrors.Count -eq 0 -and $allWarnings.Count -eq 0) {
    Write-Host ""
    Write-Host "✅ 未发现关键问题" -ForegroundColor Green
    Write-Host "   已扫描 $($files.Count) 个源文件" -ForegroundColor Gray
    if ($allInfo.Count -gt 0) {
        Write-Host "   检测到 $($allInfo.Count) 个外置模块" -ForegroundColor Gray
    }
} else {
    if ($allErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "❌ 严重错误 ($($allErrors.Count))" -ForegroundColor Red
        Write-Host "   这些错误将导致硬件损坏!" -ForegroundColor Red
        foreach ($err in $allErrors) {
            Write-Host "   $err" -ForegroundColor Red
        }
    }

    if ($allWarnings.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  警告 ($($allWarnings.Count))" -ForegroundColor Yellow
        foreach ($warn in $allWarnings) {
            Write-Host "   $warn" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "[4/4] 建议:" -ForegroundColor Yellow
Write-Host ""

if ($allErrors.Count -gt 0) {
    Write-Host "  🔴 请勿烧录 - 请先修复严重错误!" -ForegroundColor Red
    Write-Host "     - 外置模块可能已损坏" -ForegroundColor Gray
    Write-Host "     - 检查引脚复用配置" -ForegroundColor Gray
    Write-Host "     - 验证电压兼容性 (3.3V vs 5V)" -ForegroundColor Gray
} else {
    Write-Host "  🟢 未检测到严重冲突" -ForegroundColor Green
}

if ($allWarnings.Count -gt 0) {
    Write-Host ""
    Write-Host "  🟡 请审查警告以提高可靠性" -ForegroundColor Yellow
    Write-Host "     - 为浮空输入添加上拉/下拉电阻" -ForegroundColor Gray
    Write-Host "     - 确认所有 GPIO 时钟已使能" -ForegroundColor Gray
    Write-Host "     - 检查电压等级兼容性" -ForegroundColor Gray
}

if ($allInfo.Count -gt 0) {
    Write-Host ""
    Write-Host "  📋 检测到的外置模块:" -ForegroundColor Cyan
    Write-Host "     请审查引脚分配的兼容性" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allErrors.Count -gt 0) {
    exit 1
} else {
    exit 0
}