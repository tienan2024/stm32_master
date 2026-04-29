#Requires -Version 5.0
<#
.SYNOPSIS
STM32 Serial Monitor WebSocket Server - 高性能实时串口监控
.DESCRIPTION
基于.NET WebSocket的高性能串口监控服务器
支持多客户端同时连接，实时推送串口数据
#>

param(
    [int]$Port = 8080,
    [string]$SerialPort,
    [int]$BaudRate = 115200,
    [switch]$OpenBrowser = $true
)

Add-Type -AssemblyName System.Net.WebSockets
Add-Type -AssemblyName System.Net.WebSockets.WebSocketProtocol

$ErrorActionPreference = "Continue"

# ============================================================================
# WebSocket 服务器实现
# ============================================================================

class WebSocketServer {
    [System.Net.HttpListener]$listener
    [System.Collections.Generic.List[object]]$clients
    [System.IO.Ports.SerialPort]$serialPort
    [bool]$running
    [System.Threading.Thread]$listenerThread
    [System.Threading.Thread]$serialThread
    [object]$lockObj
    
    WebSocketServer([int]$port) {
        $this.listener = New-Object System.Net.HttpListener
        $this.listener.Prefixes.Add("http://localhost:$port/")
        $this.listener.Prefixes.Add("http://127.0.0.1:$port/")
        $this.clients = New-Object System.Collections.Generic.List[object]
        $this.running = $false
        $this.lockObj = New-Object object
    }
    
    [void] InitializeSerialPort([string]$port, [int]$baud) {
        $this.serialPort = New-Object System.IO.Ports.SerialPort
        $this.serialPort.PortName = $port
        $this.serialPort.BaudRate = $baud
        $this.serialPort.DataBits = 8
        $this.serialPort.StopBits = 1
        $this.serialPort.Parity = "None"
        $this.serialPort.ReadTimeout = 100
        $this.serialPort.WriteTimeout = 1000
        $this.serialPort.Open()
    }
    
    [void] Start() {
        $this.running = $true
        try {
            $this.listener.Start()
            Write-Host "✅ HTTP 服务器已启动: http://localhost:8080/" -ForegroundColor Green
        } catch {
            Write-Host "❌ 无法启动服务器: $_" -ForegroundColor Red
            $this.running = $false
            return
        }
        
        # 启动HTTP监听线程
        $this.listenerThread = [System.Threading.Thread]::new({
            $this.ListenerLoop()
        })
        $this.listenerThread.Start()
        
        # 启动串口读取线程
        $this.serialThread = [System.Threading.Thread]::new({
            $this.SerialReaderLoop()
        })
        $this.serialThread.Start()
    }
    
    [void] ListenerLoop() {
        while ($this.running) {
            try {
                $context = $this.listener.GetContext()
                $request = $context.Request
                $response = $context.Response
                
                if ($request.HttpMethod -eq "GET" -and $request.Url.AbsolutePath -eq "/") {
                    # 返回HTML界面
                    $html = $this.GetWebUI()
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                    $response.ContentLength64 = $buffer.Length
                    $response.ContentType = "text/html; charset=utf-8"
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $response.OutputStream.Close()
                    
                } elseif ($request.IsWebSocketRequest) {
                    # 处理WebSocket升级
                    $webSocketContext = $request.GetWebSocketContext()
                    $webSocket = $webSocketContext.WebSocket
                    
                    [byte[]]$buffer = New-Object byte[] 1024
                    
                    [void][System.Threading.Monitor]::Enter($this.lockObj)
                    try {
                        $this.clients.Add($webSocket)
                    } finally {
                        [System.Threading.Monitor]::Exit($this.lockObj)
                    }
                    
                    # 可选：在客户端连接时发送欢迎消息
                    $welcomeMsg = @{
                        timestamp = (Get-Date -Format "HH:mm:ss.fff")
                        message = "✅ 已连接到串口监控服务"
                    } | ConvertTo-Json -Compress
                    
                    $frame = [System.Text.Encoding]::UTF8.GetBytes($welcomeMsg)
                    try {
                        $webSocket.SendAsync([System.IO.MemoryStream]::new($frame), 
                                           [System.Net.WebSockets.WebSocketMessageType]::Text, 
                                           $true, 
                                           [System.Threading.CancellationToken]::None).Wait()
                    } catch {}
                    
                } else {
                    $response.StatusCode = 404
                    $response.Close()
                }
            } catch {
                # 继续处理下一个请求
                Start-Sleep -Milliseconds 10
            }
        }
    }
    
    [void] SerialReaderLoop() {
        $lineBuffer = ""
        
        while ($this.running) {
            try {
                if ($this.serialPort.IsOpen -and $this.serialPort.BytesToRead -gt 0) {
                    $byte = $this.serialPort.ReadByte()
                    $char = [char]$byte
                    
                    if ($char -eq "`n") {
                        $lineBuffer = $lineBuffer.TrimEnd("`r")
                        
                        # 构建消息
                        $message = @{
                            timestamp = (Get-Date -Format "HH:mm:ss.fff")
                            message = $lineBuffer
                        } | ConvertTo-Json -Compress
                        
                        # 广播到所有客户端
                        $this.BroadcastMessage($message)
                        
                        $lineBuffer = ""
                    } else {
                        $lineBuffer += $char
                    }
                } else {
                    [System.Threading.Thread]::Sleep(10)
                }
            } catch {
                [System.Threading.Thread]::Sleep(10)
            }
        }
    }
    
    [void] BroadcastMessage([string]$message) {
        $frame = [System.Text.Encoding]::UTF8.GetBytes($message)
        $deadClients = New-Object System.Collections.Generic.List[object]
        
        [void][System.Threading.Monitor]::Enter($this.lockObj)
        try {
            foreach ($ws in $this.clients) {
                try {
                    if ($ws.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
                        $ms = [System.IO.MemoryStream]::new($frame)
                        $ws.SendAsync($ms, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, 
                                     [System.Threading.CancellationToken]::None).Wait(1000)
                    } else {
                        $deadClients.Add($ws)
                    }
                } catch {
                    $deadClients.Add($ws)
                }
            }
            
            # 移除已断开的客户端
            foreach ($client in $deadClients) {
                $this.clients.Remove($client)
            }
        } finally {
            [System.Threading.Monitor]::Exit($this.lockObj)
        }
    }
    
    [void] Stop() {
        $this.running = $false
        if ($this.listener) { $this.listener.Stop() }
        if ($this.serialPort -and $this.serialPort.IsOpen) { $this.serialPort.Close() }
    }
    
    [string] GetWebUI() {
        return @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STM32 Serial Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Fira Code', 'Monaco', monospace; background: #0d1117; color: #c9d1d9; padding: 16px; height: 100vh; }
        .container { display: flex; flex-direction: column; height: 100%; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; padding: 16px; background: rgba(22, 27, 34, 0.8); border-radius: 8px; border: 1px solid #30363d; }
        h1 { font-size: 22px; font-weight: 700; }
        .controls { display: flex; gap: 16px; align-items: center; }
        .console { flex: 1; background: rgba(13, 17, 23, 0.9); border: 1px solid #30363d; border-radius: 8px; padding: 16px; overflow-y: auto; font-size: 12px; line-height: 1.6; }
        .console-line { display: flex; gap: 12px; margin: 2px 0; }
        .timestamp { color: #8b949e; flex-shrink: 0; user-select: none; }
        .message { flex: 1; color: #c9d1d9; }
        .message.error { color: #f85149; font-weight: 600; }
        .message.warn { color: #d29922; }
        .message.success { color: #3fb950; }
        button { padding: 8px 14px; background: linear-gradient(135deg, #238636 0%, #1f6feb 100%); color: white; border: none; border-radius: 6px; cursor: pointer; margin-left: 8px; }
        button:hover { background: linear-gradient(135deg, #2ea043 0%, #2671e5 100%); }
        .toolbar { margin-bottom: 16px; display: flex; gap: 8px; }
        input { padding: 8px 12px; background: rgba(13, 17, 23, 0.8); color: #c9d1d9; border: 1px solid #30363d; border-radius: 6px; flex: 1; font-family: inherit; }
        footer { margin-top: 12px; text-align: center; color: #6e7681; font-size: 11px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔌 STM32 Serial Monitor</h1>
            <div class="controls">
                <span id="status">连接中...</span>
                <button onclick="clearConsole()">清空</button>
                <button onclick="downloadLog()">📥 下载</button>
            </div>
        </header>
        <div class="toolbar">
            <input type="text" id="filterInput" placeholder="🔍 搜索/过滤...">
            <button onclick="applyFilter()">过滤</button>
            <button onclick="clearFilter()">清除</button>
        </div>
        <div class="console" id="console"></div>
        <footer>STM32 Serial Monitor • 实时监控</footer>
    </div>
    
    <script>
        const MAX_LINES = 5000;
        let allLines = [];
        let filterRegex = null;
        let ws = null;
        let isConnected = false;
        
        function initWebSocket() {
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            ws = new WebSocket(protocol + '//' + window.location.host + '/ws');
            
            ws.onopen = function() {
                console.log('✅ WebSocket已连接');
                document.getElementById('status').textContent = '✅ 已连接';
                document.getElementById('status').style.color = '#3fb950';
                isConnected = true;
            };
            
            ws.onmessage = function(event) {
                try {
                    const data = JSON.parse(event.data);
                    addLine(data.timestamp, data.message);
                } catch (e) {
                    console.error('解析错误:', e);
                }
            };
            
            ws.onerror = function(error) {
                console.error('WebSocket错误:', error);
                document.getElementById('status').textContent = '❌ 连接错误';
                document.getElementById('status').style.color = '#f85149';
            };
            
            ws.onclose = function() {
                console.log('WebSocket已断开');
                document.getElementById('status').textContent = '⏳ 重新连接中...';
                isConnected = false;
                setTimeout(initWebSocket, 2000);
            };
        }
        
        function addLine(timestamp, message) {
            allLines.push({timestamp, message});
            if (allLines.length > MAX_LINES) allLines.shift();
            
            if (!filterRegex || filterRegex.test(message)) {
                renderLine(timestamp, message);
            }
        }
        
        function renderLine(timestamp, message) {
            const console = document.getElementById('console');
            const line = document.createElement('div');
            line.className = 'console-line';
            
            let msgClass = 'message';
            if (/error|ERROR|ERR/i.test(message)) msgClass = 'message error';
            else if (/warning|WARN/i.test(message)) msgClass = 'message warn';
            else if (/success|OK|✅/i.test(message)) msgClass = 'message success';
            
            line.innerHTML = `<span class="timestamp">[\${timestamp}]</span><span class="\${msgClass}">\${escapeHtml(message)}</span>`;
            console.appendChild(line);
            console.scrollTop = console.scrollHeight;
        }
        
        function clearConsole() { document.getElementById('console').innerHTML = ''; }
        function applyFilter() {
            const text = document.getElementById('filterInput').value.trim();
            try {
                filterRegex = new RegExp(text, 'i');
            } catch { return; }
            
            const console = document.getElementById('console');
            console.innerHTML = '';
            allLines.forEach(l => {
                if (filterRegex.test(l.message)) renderLine(l.timestamp, l.message);
            });
        }
        function clearFilter() {
            document.getElementById('filterInput').value = '';
            filterRegex = null;
            const console = document.getElementById('console');
            console.innerHTML = '';
            allLines.forEach(l => renderLine(l.timestamp, l.message));
        }
        function downloadLog() {
            const text = allLines.map(l => `[\${l.timestamp}] \${l.message}`).join('\\n');
            const blob = new Blob([text], {type: 'text/plain; charset=utf-8'});
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'serial_' + new Date().toISOString().replace(/[:.]/g, '-') + '.log';
            a.click();
            URL.revokeObjectURL(url);
        }
        function escapeHtml(unsafe) {
            return unsafe.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                        .replace(/"/g, "&quot;").replace(/'/g, "&#039;");
        }
        
        initWebSocket();
    </script>
</body>
</html>
"@
    }
}

# ============================================================================
# 主程序
# ============================================================================

function Get-AvailableComPorts {
    $ports = @()
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    } catch {}
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
        [int]$choice = Read-Host "请输入选择"
        if ($choice -ge 1 -and $choice -le $availablePorts.Count) {
            return $availablePorts[$choice - 1]
        }
    }
}

if (!$SerialPort) {
    $SerialPort = Select-ComPort
    if (!$SerialPort) { exit 1 }
}

Write-Host ""
Write-Host "🚀 STM32 Serial Monitor (WebSocket)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "📡 串口: $SerialPort @ $BaudRate" -ForegroundColor Green
Write-Host "🌐 Web UI: http://localhost:$Port/" -ForegroundColor Green
Write-Host ""

# 创建并启动服务器
$server = [WebSocketServer]::new($Port)

try {
    $server.InitializeSerialPort($SerialPort, $BaudRate)
    Write-Host "✅ 串口已打开" -ForegroundColor Green
} catch {
    Write-Host "❌ 无法打开串口: $_" -ForegroundColor Red
    exit 1
}

$server.Start()

if ($OpenBrowser) {
    Start-Sleep -Milliseconds 500
    try {
        Start-Process "http://localhost:$Port/"
    } catch {
        Write-Host "⚠️  无法自动打开浏览器" -ForegroundColor Yellow
    }
}

Write-Host "按 Ctrl+C 停止服务..." -ForegroundColor Yellow
while ($server.running) {
    Start-Sleep -Seconds 1
}

$server.Stop()
Write-Host "✅ 服务已停止" -ForegroundColor Green
