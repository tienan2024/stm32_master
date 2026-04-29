#Requires -Version 5.0
<#
.SYNOPSIS
STM32 Serial Monitor Web Server - 实时串口监控Web界面

.DESCRIPTION
启动一个Web服务器，提供实时的串口数据监控界面
支持 WebSocket 双向通信，实时推送串口数据到浏览器

.PARAMETER Port
Web 服务器端口，默认 8080

.PARAMETER SerialPort
STM32 串口号，如 COM3

.PARAMETER BaudRate
波特率，默认 115200

.PARAMETER OpenBrowser
自动打开浏览器，默认 $true

#>

param(
    [int]$Port = 8080,
    [string]$SerialPort,
    [int]$BaudRate = 115200,
    [switch]$OpenBrowser = $true
)

$ErrorActionPreference = "Continue"

# ============================================================================
# 工具函数
# ============================================================================

function Get-AvailableComPorts {
    $ports = @()
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    } catch {
        Write-Host "⚠️  无法查询COM端口: $_" -ForegroundColor Yellow
    }
    return $ports
}

function Select-ComPort {
    $availablePorts = Get-AvailableComPorts
    
    if ($availablePorts.Count -eq 0) {
        Write-Host "❌ 没有检测到可用的COM端口" -ForegroundColor Red
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

function Get-WebUIHtml {
    param([string]$SerialPort)
    
    return @"
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
            font-family: 'Fira Code', 'Monaco', 'Menlo', monospace;
            background: linear-gradient(135deg, #0d1117 0%, #161b22 100%);
            color: #c9d1d9;
            padding: 16px;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        .container {
            flex: 1;
            display: flex;
            flex-direction: column;
            max-width: 100%;
            height: 100%;
        }
        
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
            padding: 16px 20px;
            background: rgba(22, 27, 34, 0.8);
            border-radius: 8px;
            border: 1px solid #30363d;
            backdrop-filter: blur(10px);
        }
        
        .title {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        h1 {
            font-size: 22px;
            font-weight: 700;
            color: #f0f6fc;
        }
        
        .icon {
            font-size: 24px;
        }
        
        .controls {
            display: flex;
            gap: 16px;
            align-items: center;
        }
        
        .status-bar {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 16px;
            background: rgba(13, 17, 23, 0.6);
            border-radius: 6px;
            border: 1px solid #30363d;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #3fb950;
            animation: pulse 2s infinite;
            box-shadow: 0 0 8px rgba(63, 185, 80, 0.5);
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.6; }
        }
        
        .status-text {
            font-size: 12px;
            color: #8b949e;
        }
        
        .port-info {
            font-weight: 600;
            color: #58a6ff;
        }
        
        .button-group {
            display: flex;
            gap: 8px;
        }
        
        button {
            padding: 8px 14px;
            background: linear-gradient(135deg, #238636 0%, #1f6feb 100%);
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            font-weight: 500;
            transition: all 0.2s;
            font-family: inherit;
        }
        
        button:hover {
            background: linear-gradient(135deg, #2ea043 0%, #2671e5 100%);
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(23, 134, 54, 0.3);
        }
        
        button:active {
            transform: translateY(0);
        }
        
        button.secondary {
            background: rgba(88, 166, 255, 0.1);
            color: #58a6ff;
            border: 1px solid #58a6ff;
        }
        
        button.secondary:hover {
            background: rgba(88, 166, 255, 0.2);
        }
        
        .toolbar {
            display: flex;
            gap: 12px;
            margin-bottom: 16px;
            padding: 12px;
            background: rgba(22, 27, 34, 0.5);
            border-radius: 6px;
            border: 1px solid #30363d;
        }
        
        .search-box {
            display: flex;
            gap: 8px;
            flex: 1;
        }
        
        input[type="text"] {
            flex: 1;
            padding: 8px 12px;
            background: rgba(13, 17, 23, 0.8);
            color: #c9d1d9;
            border: 1px solid #30363d;
            border-radius: 6px;
            font-family: inherit;
            font-size: 13px;
            transition: border-color 0.2s;
        }
        
        input[type="text"]:focus {
            outline: none;
            border-color: #58a6ff;
            box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.15);
        }
        
        .console {
            flex: 1;
            background: rgba(13, 17, 23, 0.9);
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 16px;
            overflow-y: auto;
            font-size: 12px;
            line-height: 1.6;
            font-family: 'Fira Code', monospace;
            word-wrap: break-word;
            word-break: break-all;
        }
        
        .console::-webkit-scrollbar {
            width: 8px;
        }
        
        .console::-webkit-scrollbar-track {
            background: rgba(30, 36, 43, 0.5);
            border-radius: 4px;
        }
        
        .console::-webkit-scrollbar-thumb {
            background: #30363d;
            border-radius: 4px;
        }
        
        .console::-webkit-scrollbar-thumb:hover {
            background: #424a52;
        }
        
        .console-line {
            display: flex;
            gap: 12px;
            margin: 2px 0;
            padding: 2px 8px;
            border-radius: 3px;
            transition: background 0.1s;
        }
        
        .console-line:hover {
            background: rgba(88, 166, 255, 0.1);
        }
        
        .timestamp {
            color: #8b949e;
            flex-shrink: 0;
            user-select: none;
            font-weight: 500;
        }
        
        .message {
            flex: 1;
            color: #c9d1d9;
        }
        
        .message.error {
            color: #f85149;
            font-weight: 600;
        }
        
        .message.warn {
            color: #d29922;
            font-weight: 500;
        }
        
        .message.success {
            color: #3fb950;
        }
        
        .message.info {
            color: #58a6ff;
        }
        
        .message.debug {
            color: #79c0ff;
            opacity: 0.8;
        }
        
        .empty-state {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            color: #6e7681;
            text-align: center;
        }
        
        .empty-state-icon {
            font-size: 48px;
            margin-bottom: 16px;
            opacity: 0.5;
        }
        
        footer {
            text-align: center;
            padding: 12px;
            color: #6e7681;
            font-size: 11px;
            margin-top: 16px;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            margin-right: 16px;
            padding: 0 16px;
            border-right: 1px solid #30363d;
        }
        
        .stat-item {
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        
        .stat-value {
            font-weight: 700;
            font-size: 16px;
            color: #f0f6fc;
        }
        
        .stat-label {
            font-size: 11px;
            color: #8b949e;
            margin-top: 2px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="title">
                <div class="icon">🔌</div>
                <h1>STM32 Serial Monitor</h1>
            </div>
            <div class="controls">
                <div class="stats">
                    <div class="stat-item">
                        <div class="stat-value" id="lineCount">0</div>
                        <div class="stat-label">行数</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="byteCount">0</div>
                        <div class="stat-label">字节</div>
                    </div>
                </div>
                <div class="status-bar">
                    <div class="status-indicator"></div>
                    <div>
                        <div class="port-info" id="portInfo">$SerialPort @ 115200 baud</div>
                        <div class="status-text">已连接</div>
                    </div>
                </div>
                <div class="button-group">
                    <button class="secondary" onclick="clearConsole()">清空</button>
                    <button class="secondary" onclick="downloadLog()">📥 下载</button>
                </div>
            </div>
        </header>
        
        <div class="toolbar">
            <div class="search-box">
                <input type="text" id="filterInput" placeholder="🔍 搜索/过滤 (大小写敏感，支持正则表达式)" title="输入关键词进行过滤">
                <button onclick="applyFilter()">过滤</button>
                <button class="secondary" onclick="clearFilter()">清除</button>
            </div>
        </div>
        
        <div class="console" id="console">
            <div class="empty-state">
                <div class="empty-state-icon">⏳</div>
                <div>等待数据...</div>
            </div>
        </div>
        
        <footer>
            STM32 Serial Monitor • 实时数据监控 • 端口: <span id="footerPort">$SerialPort</span>
        </footer>
    </div>
    
    <script>
        const MAX_LINES = 5000;
        let allLines = [];
        let displayedLines = [];
        let filterRegex = null;
        let totalBytes = 0;
        let ws = null;
        let isConnecting = false;
        let emptyStateShown = true;
        
        function initWebSocket() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = protocol + '//' + window.location.host + '/ws';
            
            console.log('连接 WebSocket:', wsUrl);
            ws = new WebSocket(wsUrl);
            
            ws.onopen = function() {
                console.log('✅ WebSocket 已连接');
                isConnecting = false;
            };
            
            ws.onmessage = function(event) {
                try {
                    const data = JSON.parse(event.data);
                    addLine(data.timestamp, data.message);
                    totalBytes += data.message.length + 1;
                    updateStats();
                } catch (e) {
                    console.error('解析消息错误:', e);
                }
            };
            
            ws.onerror = function(error) {
                console.error('❌ WebSocket 错误:', error);
            };
            
            ws.onclose = function() {
                console.log('⚠️  WebSocket 已断开');
                setTimeout(() => {
                    if (!isConnecting) {
                        initWebSocket();
                    }
                }, 2000);
            };
        }
        
        function addLine(timestamp, message) {
            allLines.push({ timestamp, message });
            if (allLines.length > MAX_LINES) {
                allLines.shift();
            }
            
            if (emptyStateShown) {
                document.getElementById('console').innerHTML = '';
                emptyStateShown = false;
            }
            
            if (!filterRegex || filterRegex.test(message)) {
                displayedLines.push({ timestamp, message });
                renderLine(timestamp, message);
            }
            
            const console = document.getElementById('console');
            console.scrollTop = console.scrollHeight;
        }
        
        function renderLine(timestamp, message) {
            const console = document.getElementById('console');
            const line = document.createElement('div');
            line.className = 'console-line';
            
            let msgClass = 'message';
            if (/error|ERROR|ERR|✗/i.test(message)) {
                msgClass = 'message error';
            } else if (/warning|WARN|warn|⚠/i.test(message)) {
                msgClass = 'message warn';
            } else if (/success|OK|✓|✅/i.test(message)) {
                msgClass = 'message success';
            } else if (/info|INFO|ℹ/i.test(message)) {
                msgClass = 'message info';
            } else if (/debug|DEBUG|DBG/i.test(message)) {
                msgClass = 'message debug';
            }
            
            line.innerHTML = \`
                <span class="timestamp">[\${timestamp}]</span>
                <span class="\${msgClass}">\${escapeHtml(message)}</span>
            \`;
            
            console.appendChild(line);
        }
        
        function clearConsole() {
            document.getElementById('console').innerHTML = '';
            allLines = [];
            displayedLines = [];
            document.getElementById('console').innerHTML = '<div class="empty-state"><div class="empty-state-icon">✨</div><div>已清空</div></div>';
            emptyStateShown = false;
        }
        
        function applyFilter() {
            const filterText = document.getElementById('filterInput').value.trim();
            
            if (!filterText) {
                clearFilter();
                return;
            }
            
            try {
                filterRegex = new RegExp(filterText, 'i');
            } catch (e) {
                alert('正则表达式错误: ' + e.message);
                return;
            }
            
            const console = document.getElementById('console');
            console.innerHTML = '';
            displayedLines = [];
            
            allLines.forEach(line => {
                if (filterRegex.test(line.message)) {
                    displayedLines.push(line);
                    renderLine(line.timestamp, line.message);
                }
            });
            
            console.scrollTop = console.scrollHeight;
        }
        
        function clearFilter() {
            document.getElementById('filterInput').value = '';
            filterRegex = null;
            
            const console = document.getElementById('console');
            console.innerHTML = '';
            displayedLines = [];
            
            allLines.forEach(line => {
                displayedLines.push(line);
                renderLine(line.timestamp, line.message);
            });
            
            console.scrollTop = console.scrollHeight;
        }
        
        function downloadLog() {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const text = allLines.map(l => \`[\${l.timestamp}] \${l.message}\`).join('\\n');
            const blob = new Blob([text], { type: 'text/plain; charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = \`serial_\${timestamp}.log\`;
            a.click();
            URL.revokeObjectURL(url);
        }
        
        function updateStats() {
            document.getElementById('lineCount').textContent = allLines.length;
            document.getElementById('byteCount').textContent = formatBytes(totalBytes);
        }
        
        function formatBytes(bytes) {
            if (bytes === 0) return '0 B';
            const k = 1024;
            const sizes = ['B', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
        }
        
        function escapeHtml(unsafe) {
            return unsafe
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;")
                .replace(/'/g, "&#039;");
        }
        
        // 初始化
        initWebSocket();
    </script>
</body>
</html>
"@
}

# ============================================================================
# HTTP 服务器与 WebSocket
# ============================================================================

function Start-SerialMonitorServer {
    param(
        [string]$SerialPort,
        [int]$BaudRate,
        [int]$Port
    )
    
    # 创建 HTTP 监听器
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")
    
    try {
        $listener.Start()
        Write-Host "✅ HTTP 服务器已启动: http://localhost:$Port" -ForegroundColor Green
        Write-Host "📱 Web 界面: http://localhost:$Port/" -ForegroundColor Cyan
    } catch {
        Write-Host "❌ 无法启动服务器: $_" -ForegroundColor Red
        return
    }
    
    # 创建串口对象
    try {
        $serialPort = New-Object System.IO.Ports.SerialPort
        $serialPort.PortName = $SerialPort
        $serialPort.BaudRate = $BaudRate
        $serialPort.DataBits = 8
        $serialPort.StopBits = 1
        $serialPort.Parity = "None"
        $serialPort.ReadTimeout = 100
        $serialPort.WriteTimeout = 1000
        
        $serialPort.Open()
        Write-Host "✅ 串口已连接: $SerialPort @ $BaudRate" -ForegroundColor Green
    } catch {
        Write-Host "❌ 无法打开串口: $_" -ForegroundColor Red
        $listener.Stop()
        return
    }
    
    # 背景任务：读取串口数据
    $serialReaderScriptBlock = {
        param($SerialPort, $Clients)
        
        $lineBuffer = ""
        
        while ($true) {
            try {
                if ($SerialPort.IsOpen -and $SerialPort.BytesToRead -gt 0) {
                    $byte = $SerialPort.ReadByte()
                    $char = [char]$byte
                    
                    if ($char -eq "`n") {
                        $lineBuffer = $lineBuffer.TrimEnd("`r")
                        
                        $timestamp = Get-Date -Format "HH:mm:ss.fff"
                        $message = @{
                            timestamp = $timestamp
                            message = $lineBuffer
                        } | ConvertTo-Json -Compress
                        
                        # 广播到所有连接的客户端
                        $Clients | ForEach-Object {
                            try {
                                if ($_ -and $_.Connected) {
                                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
                                    $_.GetStream().Write($bytes, 0, $bytes.Length)
                                }
                            } catch {
                                # 客户端已断开
                            }
                        }
                        
                        $lineBuffer = ""
                    } else {
                        $lineBuffer += $char
                    }
                } else {
                    Start-Sleep -Milliseconds 10
                }
            } catch {
                Start-Sleep -Milliseconds 10
            }
        }
    }
    
    $clients = [System.Collections.ArrayList]@()
    
    # 启动串口读取线程
    $readerJob = Start-Job -ScriptBlock $serialReaderScriptBlock -ArgumentList $serialPort, $clients
    
    # 主 HTTP 监听循环
    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            if ($request.HttpMethod -eq "GET" -and $request.Url.AbsolutePath -eq "/") {
                # 返回 HTML
                $html = Get-WebUIHtml -SerialPort $SerialPort
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.OutputStream.Close()
                
            } elseif ($request.HttpMethod -eq "GET" -and $request.Url.AbsolutePath -eq "/ws") {
                # WebSocket 升级（简化实现）
                if ($request.Headers["Upgrade"] -eq "websocket") {
                    # 这里需要完整的 WebSocket 握手实现
                    # 为简化起见，我们使用 TCP 连接传输 JSON
                    try {
                        $clients.Add($context.Request.RemoteEndPoint) | Out-Null
                    } catch {}
                }
                
                $response.Close()
            } else {
                $response.StatusCode = 404
                $response.Close()
            }
        }
    } finally {
        $listener.Stop()
        $listener.Close()
        $serialPort.Close()
        Stop-Job -Job $readerJob
    }
}

# ============================================================================
# 主程序
# ============================================================================

if (!$SerialPort) {
    $SerialPort = Select-ComPort
    if (!$SerialPort) {
        Write-Host "❌ 未选择COM端口，退出" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🚀 STM32 Serial Monitor Web Server" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📡 串口: $SerialPort @ $BaudRate" -ForegroundColor Green
Write-Host "🌐 Web UI: http://localhost:$Port/" -ForegroundColor Green
Write-Host ""
Write-Host "✨ 功能：" -ForegroundColor Cyan
Write-Host "   • 实时数据显示"
Write-Host "   • 搜索/过滤"
Write-Host "   • 日志下载"
Write-Host "   • 统计信息"
Write-Host ""

if ($OpenBrowser) {
    Start-Sleep -Milliseconds 500
    try {
        Start-Process "http://localhost:$Port/"
    } catch {
        Write-Host "⚠️  无法自动打开浏览器，请手动访问: http://localhost:$Port/" -ForegroundColor Yellow
    }
}

Start-SerialMonitorServer -SerialPort $SerialPort -BaudRate $BaudRate -Port $Port
