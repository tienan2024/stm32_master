#Requires -Version 5.0
<#
.SYNOPSIS
STM32 Serial Port Monitor - 实时读取与监控串口数据

.DESCRIPTION
功能：
- 自动检测可用COM端口
- 支持指定端口、波特率、数据位、奇偶校验、停止位
- 实时输出到屏幕与日志文件
- 支持数据过滤、时间戳显示
- 支持Web UI实时监控（可选）

.PARAMETER Port
串口号（如 COM1, COM3）。如果为空则自动检测

.PARAMETER BaudRate
波特率，默认 115200

.PARAMETER DataBits
数据位数，默认 8

.PARAMETER StopBits
停止位，默认 1（选项：0.5, 1, 1.5, 2）

.PARAMETER Parity
奇偶校验，默认 None（选项：None, Odd, Even, Mark, Space）

.PARAMETER Timeout
读取超时（毫秒），默认 1000

.PARAMETER Duration
监控持续时间（秒），默认 0（无限）

.PARAMETER LogFile
日志文件路径，默认不保存

.PARAMETER Filter
数据过滤器（正则表达式），只显示匹配的行

.PARAMETER WebUI
启用Web UI实时查看，默认 $false

.PARAMETER WebPort
Web UI 端口，默认 8080

.EXAMPLE
# 自动检测COM端口，波特率115200
.\monitor_serial.ps1

# 指定COM3，波特率9600，保存日志
.\monitor_serial.ps1 -Port "COM3" -BaudRate 9600 -LogFile "serial.log"

# 启用Web UI，监控5分钟
.\monitor_serial.ps1 -WebUI -Duration 300

# 只显示包含特定内容的行
.\monitor_serial.ps1 -Filter "error|warning|DEBUG"
#>

param(
    [string]$Port,
    [int]$BaudRate = 115200,
    [int]$DataBits = 8,
    [object]$StopBits = 1,
    [string]$Parity = "None",
    [int]$Timeout = 1000,
    [int]$Duration = 0,
    [string]$LogFile,
    [string]$Filter,
    [switch]$WebUI,
    [int]$WebPort = 8080
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date

# ============================================================================
# 辅助函数
# ============================================================================

function Get-AvailableComPorts {
    <#获取所有可用的COM端口#>
    $ports = @()
    
    try {
        $portCount = [System.IO.Ports.SerialPort]::GetPortNames()
        if ($portCount) {
            $ports = $portCount
        }
    } catch {
        Write-Host "⚠️  无法查询COM端口: $_" -ForegroundColor Yellow
    }
    
    return $ports
}

function Test-SerialPort {
    <#测试COM端口是否可用#>
    param([string]$PortName)
    
    try {
        $sp = New-Object System.IO.Ports.SerialPort($PortName, 115200)
        $sp.Open()
        $sp.Close()
        return $true
    } catch {
        return $false
    }
}

function Select-ComPort {
    <#交互式选择COM端口#>
    $availablePorts = Get-AvailableComPorts
    
    if ($availablePorts.Count -eq 0) {
        Write-Host "❌ 没有检测到可用的COM端口" -ForegroundColor Red
        Write-Host "💡 请检查：" -ForegroundColor Cyan
        Write-Host "   1. STM32 设备已连接"
        Write-Host "   2. 驱动程序已安装"
        Write-Host "   3. 设备管理器可见"
        return $null
    }
    
    if ($availablePorts.Count -eq 1) {
        Write-Host "✅ 自动选择: $($availablePorts[0])" -ForegroundColor Green
        return $availablePorts[0]
    }
    
    Write-Host "🔌 检测到多个COM端口，请选择:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $availablePorts.Count; $i++) {
        Write-Host "  [$($i+1)] $($availablePorts[$i])"
    }
    
    while ($true) {
        [int]$choice = Read-Host "请输入选择 (1-$($availablePorts.Count))"
        if ($choice -ge 1 -and $choice -le $availablePorts.Count) {
            return $availablePorts[$choice - 1]
        }
        Write-Host "❌ 选择无效，请重试" -ForegroundColor Red
    }
}

function Format-SerialOutput {
    <#格式化串口输出#>
    param(
        [string]$Data,
        [bool]$ShowTimestamp = $true,
        [bool]$ShowHex = $false
    )
    
    $output = ""
    
    if ($ShowTimestamp) {
        $timestamp = Get-Date -Format "HH:mm:ss.fff"
        $output += "[$timestamp] "
    }
    
    if ($ShowHex) {
        $hex = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($Data))
        $output += "$Data (hex: $hex)"
    } else {
        $output += $Data
    }
    
    return $output
}

function Start-SerialMonitor {
    <#启动串口监控#>
    param(
        [string]$PortName,
        [int]$BaudRate,
        [int]$DataBits,
        [object]$StopBits,
        [string]$Parity,
        [int]$Timeout,
        [int]$Duration,
        [string]$LogFile,
        [string]$Filter
    )
    
    # 创建串口对象
    try {
        $serialPort = New-Object System.IO.Ports.SerialPort
        $serialPort.PortName = $PortName
        $serialPort.BaudRate = $BaudRate
        $serialPort.DataBits = $DataBits
        $serialPort.StopBits = $StopBits
        $serialPort.Parity = $Parity
        $serialPort.ReadTimeout = $Timeout
        $serialPort.WriteTimeout = $Timeout
        
        $serialPort.Open()
        
        Write-Host "✅ 串口已连接" -ForegroundColor Green
        Write-Host "📊 配置: $PortName @ $BaudRate baud ($DataBits,$Parity,$StopBits)" -ForegroundColor Cyan
        
        if ($LogFile) {
            Write-Host "📝 日志: $LogFile" -ForegroundColor Cyan
            "" | Out-File -FilePath $LogFile -Encoding UTF8 -Force
        }
        
        Write-Host "🔄 开始监听（按 Ctrl+C 停止）..." -ForegroundColor Cyan
        Write-Host "" -ForegroundColor White
        
    } catch {
        Write-Host "❌ 打开串口失败: $_" -ForegroundColor Red
        return
    }
    
    # 读取循环
    $lineBuffer = ""
    $bytesRead = 0
    $endTime = if ($Duration -gt 0) { $startTime.AddSeconds($Duration) } else { $null }
    
    try {
        while ($true) {
            # 检查超时
            if ($endTime -and (Get-Date) -gt $endTime) {
                Write-Host "`n✅ 监控时间已结束" -ForegroundColor Green
                break
            }
            
            # 检查是否有数据可读
            if ($serialPort.IsOpen -and $serialPort.BytesToRead -gt 0) {
                try {
                    $byte = $serialPort.ReadByte()
                    $char = [char]$byte
                    
                    # 缓冲数据直到换行
                    if ($char -eq "`n") {
                        $lineBuffer = $lineBuffer.TrimEnd("`r")
                        
                        # 应用过滤器
                        if ($Filter -and $lineBuffer -notmatch $Filter) {
                            # 跳过不匹配的行
                        } else {
                            # 格式化输出
                            $formatted = Format-SerialOutput -Data $lineBuffer -ShowTimestamp $true
                            
                            Write-Host $formatted
                            $bytesRead++
                            
                            # 保存到日志文件
                            if ($LogFile) {
                                $formatted | Out-File -FilePath $LogFile -Encoding UTF8 -Append
                            }
                        }
                        
                        $lineBuffer = ""
                    } else {
                        $lineBuffer += $char
                    }
                    
                } catch [System.TimeoutException] {
                    # 超时，继续
                    Start-Sleep -Milliseconds 10
                }
            } else {
                Start-Sleep -Milliseconds 10
            }
        }
        
    } catch [System.OperationCanceledException] {
        Write-Host "`n⏹️  监控已停止" -ForegroundColor Yellow
    } finally {
        if ($serialPort.IsOpen) {
            $serialPort.Close()
            $serialPort.Dispose()
            Write-Host "✅ 串口已关闭" -ForegroundColor Green
        }
        
        if ($LogFile) {
            Write-Host "📊 统计: 读取 $bytesRead 行数据" -ForegroundColor Cyan
            Write-Host "💾 日志保存到: $LogFile" -ForegroundColor Cyan
        }
    }
}

function Start-WebUIServer {
    <#启动Web UI服务器#>
    param(
        [string]$PortName,
        [int]$Port
    )
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STM32 Serial Monitor</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            background: #0d1117;
            color: #c9d1d9;
            padding: 16px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding: 16px;
            background: #161b22;
            border-radius: 6px;
            border: 1px solid #30363d;
        }
        
        h1 {
            font-size: 20px;
            font-weight: 600;
        }
        
        .controls {
            display: flex;
            gap: 12px;
            align-items: center;
        }
        
        .status {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            background: #0d1117;
            border-radius: 4px;
            border: 1px solid #30363d;
        }
        
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #3fb950;
            animation: pulse 1s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        button {
            padding: 8px 16px;
            background: #238636;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
            transition: background 0.2s;
        }
        
        button:hover {
            background: #2ea043;
        }
        
        button:active {
            background: #1f6feb;
        }
        
        .console {
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 6px;
            padding: 16px;
            height: 500px;
            overflow-y: auto;
            font-size: 13px;
            line-height: 1.5;
            margin-bottom: 20px;
        }
        
        .console-line {
            margin: 2px 0;
            display: flex;
            align-items: flex-start;
        }
        
        .timestamp {
            color: #8b949e;
            margin-right: 12px;
            min-width: 100px;
        }
        
        .data {
            color: #c9d1d9;
            word-break: break-all;
            flex: 1;
        }
        
        .data.error {
            color: #f85149;
        }
        
        .data.warning {
            color: #d29922;
        }
        
        .data.success {
            color: #3fb950;
        }
        
        .data.info {
            color: #58a6ff;
        }
        
        footer {
            text-align: center;
            padding: 12px;
            color: #8b949e;
            font-size: 12px;
        }
        
        .input-group {
            display: flex;
            gap: 8px;
            margin-bottom: 20px;
        }
        
        input {
            flex: 1;
            padding: 8px 12px;
            background: #0d1117;
            color: #c9d1d9;
            border: 1px solid #30363d;
            border-radius: 4px;
            font-family: 'Monaco', monospace;
            font-size: 13px;
        }
        
        input:focus {
            outline: none;
            border-color: #58a6ff;
            box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔌 STM32 Serial Monitor</h1>
            <div class="controls">
                <div class="status">
                    <div class="status-dot"></div>
                    <span id="portInfo">$PortName @ 115200 baud</span>
                </div>
                <button onclick="clearConsole()">清空</button>
                <button onclick="downloadLog()">下载日志</button>
            </div>
        </header>
        
        <div class="input-group">
            <input type="text" id="filterInput" placeholder="过滤: 输入关键词..." onkeyup="applyFilter()">
            <button onclick="applyFilter()">过滤</button>
        </div>
        
        <div class="console" id="console"></div>
        
        <footer>
            STM32 Serial Monitor • 实时数据显示 • 连接至 $PortName
        </footer>
    </div>
    
    <script>
        const MAX_LINES = 2000;
        let logLines = [];
        let filteredLines = [];
        let filterText = '';
        
        // 连接 WebSocket
        const ws = new WebSocket('ws://' + window.location.host + '/ws');
        
        ws.onopen = function() {
            console.log('WebSocket 已连接');
        };
        
        ws.onmessage = function(event) {
            const data = JSON.parse(event.data);
            addLine(data.timestamp, data.message);
        };
        
        ws.onerror = function(error) {
            console.error('WebSocket 错误:', error);
        };
        
        ws.onclose = function() {
            console.log('WebSocket 已断开');
        };
        
        function addLine(timestamp, message) {
            logLines.push({ timestamp, message });
            if (logLines.length > MAX_LINES) {
                logLines.shift();
            }
            
            if (!filterText || message.includes(filterText)) {
                const console = document.getElementById('console');
                const line = document.createElement('div');
                line.className = 'console-line';
                
                let dataClass = 'data';
                if (message.includes('error') || message.includes('ERROR')) {
                    dataClass = 'data error';
                } else if (message.includes('warning') || message.includes('WARN')) {
                    dataClass = 'data warning';
                } else if (message.includes('ok') || message.includes('OK') || message.includes('success')) {
                    dataClass = 'data success';
                } else if (message.includes('info') || message.includes('INFO')) {
                    dataClass = 'data info';
                }
                
                line.innerHTML = \`
                    <span class="timestamp">[\${timestamp}]</span>
                    <span class="\${dataClass}">\${escapeHtml(message)}</span>
                \`;
                
                console.appendChild(line);
                console.scrollTop = console.scrollHeight;
            }
        }
        
        function clearConsole() {
            document.getElementById('console').innerHTML = '';
            logLines = [];
            filteredLines = [];
        }
        
        function applyFilter() {
            filterText = document.getElementById('filterInput').value.trim();
            const console = document.getElementById('console');
            console.innerHTML = '';
            
            logLines.forEach(line => {
                if (!filterText || line.message.includes(filterText)) {
                    const div = document.createElement('div');
                    div.className = 'console-line';
                    div.innerHTML = \`
                        <span class="timestamp">[\${line.timestamp}]</span>
                        <span class="data">\${escapeHtml(line.message)}</span>
                    \`;
                    console.appendChild(div);
                }
            });
            
            console.scrollTop = console.scrollHeight;
        }
        
        function downloadLog() {
            const text = logLines.map(l => \`[\${l.timestamp}] \${l.message}\`).join('\\n');
            const blob = new Blob([text], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'serial_monitor_' + new Date().toISOString() + '.log';
            a.click();
            URL.revokeObjectURL(url);
        }
        
        function escapeHtml(unsafe) {
            return unsafe
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;")
                .replace(/'/g, "&#039;");
        }
    </script>
</body>
</html>
"@

    Write-Host "🌐 启动 Web UI 服务器 (http://localhost:$Port)" -ForegroundColor Cyan
    
    # TODO: 实现 WebSocket 服务器以支持实时数据传输
    # 这需要更复杂的网络编程，可以使用 .NET Framework 的 HttpListener
    
    Write-Host "⚠️  Web UI 功能需要进一步实现（使用 .NET HttpListener）" -ForegroundColor Yellow
}

# ============================================================================
# 主程序入口
# ============================================================================

# 确定COM端口
if (!$Port) {
    $Port = Select-ComPort
    if (!$Port) {
        exit 1
    }
} else {
    Write-Host "✅ 使用指定端口: $Port" -ForegroundColor Green
}

# 验证端口
if (!(Test-SerialPort -PortName $Port)) {
    Write-Host "❌ 端口 $Port 无法打开" -ForegroundColor Red
    Write-Host "💡 可能的原因:" -ForegroundColor Cyan
    Write-Host "   1. 端口被其他程序占用"
    Write-Host "   2. 端口不存在"
    Write-Host "   3. USB驱动未安装"
    exit 1
}

# 启动Web UI（如果指定）
if ($WebUI) {
    Start-WebUIServer -PortName $Port -Port $WebPort
}

# 启动串口监控
Start-SerialMonitor -PortName $Port `
                   -BaudRate $BaudRate `
                   -DataBits $DataBits `
                   -StopBits $StopBits `
                   -Parity $Parity `
                   -Timeout $Timeout `
                   -Duration $Duration `
                   -LogFile $LogFile `
                   -Filter $Filter
