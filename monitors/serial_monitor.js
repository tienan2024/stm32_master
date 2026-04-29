const SerialPort = require('serialport');
const http = require('http');
const url = require('url');

const DEFAULT_PORT = process.argv[2] || 'COM5';
const DEFAULT_BAUD = parseInt(process.argv[3]) || 115200;
const DEFAULT_WEB_PORT = process.argv[4] || 8080;

let currentPort = DEFAULT_PORT;
let currentBaud = DEFAULT_BAUD;
let serialPort = null;
let connected = false;

// Serial port setup
function openSerialPort(port, baudRate, res) {
    if (serialPort && serialPort.isOpen) {
        serialPort.close();
    }

    serialPort = new SerialPort({
        path: port,
        baudRate: baudRate,
        autoOpen: true
    });

    serialPort.on('open', () => {
        connected = true;
        currentPort = port;
        currentBaud = baudRate;
        console.log(`\n✅ Connected to ${port} @ ${baudRate}`);
        broadcastToAll({ type: 'status', status: 'connected', port: port, baudRate: baudRate });
    });

    serialPort.on('data', (data) => {
        const text = data.toString('utf8').trim();
        if (text) {
            const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false }) + '.' + Date.now().toString().slice(-3);
            console.log(`[${timestamp}] ${text}`);
            broadcastToAll({ type: 'data', message: text, timestamp: timestamp });
        }
    });

    serialPort.on('error', (err) => {
        console.error(`❌ Serial Error: ${err.message}`);
        broadcastToAll({ type: 'error', message: err.message });
    });

    serialPort.on('close', () => {
        connected = false;
        console.log('Serial port closed');
        broadcastToAll({ type: 'status', status: 'disconnected' });
    });
}

// WebSocket clients
const clients = new Set();

function broadcastToAll(data) {
    const json = JSON.stringify(data);
    clients.forEach(client => {
        try {
            client.send(json);
        } catch (e) {
            clients.delete(client);
        }
    });
}

// List available serial ports
function listPorts() {
    return new Promise((resolve) => {
        SerialPort.list().then(ports => {
            resolve(ports.map(p => ({ path: p.path, manufacturer: p.manufacturer })));
        }).catch(err => {
            resolve([]);
        });
    });
}

// Simple Web Server
const server = http.createServer(async (req, res) => {
    const parsedUrl = url.parse(req.url, true);

    if (parsedUrl.path === '/ws') {
        const protocol = req.headers['upgrade'] === 'websocket' ? 'websocket' : null;
        if (!protocol) {
            res.writeHead(400);
            res.end('Bad Request');
            return;
        }

        const key = parsedUrl.query['k'] || req.headers['sec-websocket-key'];
        const responseKey = require('crypto')
            .createHash('sha1')
            .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
            .digest('base64');

        res.writeHead(101, {
            'Upgrade': 'websocket',
            'Connection': 'Upgrade',
            'Sec-WebSocket-Accept': responseKey
        });

        clients.add(res);
        req.on('close', () => clients.delete(res));

        // Send current status to new client
        res.send(JSON.stringify({ type: 'status', status: connected ? 'connected' : 'disconnected', port: currentPort, baudRate: currentBaud }));
        return;
    }

    if (parsedUrl.path === '/ports') {
        // API endpoint to list ports
        const ports = await listPorts();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(ports));
        return;
    }

    if (parsedUrl.path === '/connect') {
        // Connect to a port
        const port = parsedUrl.query['port'];
        const baud = parseInt(parsedUrl.query['baud']) || 115200;
        openSerialPort(port, baud);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true }));
        return;
    }

    if (parsedUrl.path === '/send') {
        // Send data
        if (serialPort && serialPort.isOpen) {
            const data = parsedUrl.query['data'] || '';
            serialPort.write(data + '\n', (err) => {
                if (err) {
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: err.message }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ success: true }));
                }
            });
        } else {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Not connected' }));
        }
        return;
    }

    // HTML page
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(getHtml());
});

function getHtml() {
    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>STM32 Serial Monitor</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Consolas', 'Monaco', monospace;
            background: #1e1e1e;
            color: #d4d4d4;
            height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .header {
            background: #2d2d2d;
            padding: 10px 20px;
            border-bottom: 1px solid #3c3c3c;
        }
        .toolbar {
            display: flex;
            gap: 10px;
            align-items: center;
            flex-wrap: wrap;
        }
        .toolbar select, .toolbar input, .toolbar button {
            background: #3c3c3c;
            color: #d4d4d4;
            border: 1px solid #555;
            padding: 6px 10px;
            border-radius: 4px;
            font-family: inherit;
            font-size: 13px;
        }
        .toolbar button {
            background: #0e639c;
            cursor: pointer;
        }
        .toolbar button:hover { background: #1177bb; }
        .toolbar button.connect { background: #2d7d46; }
        .toolbar button.connect:hover { background: #3d9d56; }
        .toolbar button.disconnect { background: #c44d4d; }
        .toolbar button.disconnect:hover { background: #d45d5d; }
        .status-bar {
            display: flex;
            gap: 15px;
            font-size: 12px;
            margin-top: 8px;
            color: #808080;
        }
        .status-dot { width: 8px; height: 8px; border-radius: 50%; background: #f14c4c; display: inline-block; margin-right: 5px; }
        .status-dot.connected { background: #4ec9b0; }
        .console-container {
            flex: 1;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        .console {
            flex: 1;
            overflow-y: auto;
            padding: 10px;
            font-size: 13px;
            line-height: 1.6;
        }
        .line {
            padding: 2px 5px;
            border-radius: 3px;
            white-space: pre-wrap;
            word-break: break-all;
        }
        .line:hover { background: #2a2a2a; }
        .line .timestamp { color: #6a9955; margin-right: 10px; }
        .line.sent { color: #dcdcaa; }
        .line.error { color: #f14c4c; }
        .line.warn { color: #cca700; }
        .line.success { color: #4ec9b0; }
        .line.info { color: #569cd6; }
        .send-bar {
            background: #2d2d2d;
            padding: 10px 20px;
            display: flex;
            gap: 10px;
            border-top: 1px solid #3c3c3c;
        }
        .send-bar input {
            flex: 1;
            background: #3c3c3c;
            color: #d4d4d4;
            border: 1px solid #555;
            padding: 8px 12px;
            border-radius: 4px;
            font-family: inherit;
            font-size: 13px;
        }
        .send-bar input:focus { outline: none; border-color: #0e639c; }
        .send-bar button {
            background: #2d7d46;
            color: white;
            border: none;
            padding: 8px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-family: inherit;
        }
        .send-bar button:hover { background: #3d9d56; }
        .send-bar button:disabled { background: #555; cursor: not-allowed; }
        .footer {
            background: #2d2d2d;
            padding: 8px 20px;
            font-size: 12px;
            color: #808080;
            display: flex;
            justify-content: space-between;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="toolbar">
            <select id="portSelect">
                <option value="">选择串口...</option>
            </select>
            <select id="baudSelect">
                <option value="9600">9600</option>
                <option value="19200">19200</option>
                <option value="38400">38400</option>
                <option value="57600">57600</option>
                <option value="115200" selected>115200</option>
                <option value="230400">230400</option>
                <option value="460800">460800</option>
                <option value="921600">921600</option>
            </select>
            <button id="connectBtn" class="connect" onclick="toggleConnect()">连接</button>
            <button onclick="refreshPorts()">刷新</button>
            <button onclick="clearConsole()">清空</button>
            <button onclick="downloadLog()">下载</button>
        </div>
        <div class="status-bar">
            <span><span class="status-dot" id="statusDot"></span><span id="statusText">未连接</span></span>
            <span>端口: <span id="portInfo">-</span></span>
            <span>波特率: <span id="baudInfo">-</span></span>
        </div>
    </div>

    <div class="console-container">
        <div class="console" id="console"></div>
    </div>

    <div class="send-bar">
        <input type="text" id="sendInput" placeholder="输入发送内容..." onkeypress="handleKeyPress(event)">
        <button id="sendBtn" onclick="sendData()" disabled>发送</button>
    </div>

    <div class="footer">
        <div class="stats">
            <span>行数: <span id="lineCount">0</span></span>
            <span>字节: <span id="byteCount">0</span></span>
        </div>
        <span id="timeDisplay"></span>
    </div>

    <script>
        let ws;
        let lineCount = 0;
        let byteCount = 0;
        let logs = [];

        function connect() {
            const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = protocol + '//' + location.host + '/ws?k=' + Date.now();

            ws = new WebSocket(wsUrl);

            ws.onopen = () => console.log('WebSocket connected');
            ws.onclose = () => {
                console.log('WebSocket disconnected, reconnecting...');
                setTimeout(connect, 2000);
            };
            ws.onerror = (err) => console.error('WebSocket error:', err);

            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    handleMessage(data);
                } catch (e) {
                    console.error('Failed to parse message:', e);
                }
            };
        }

        function handleMessage(data) {
            switch (data.type) {
                case 'status':
                    updateStatus(data.status, data.port, data.baudRate);
                    break;
                case 'data':
                    addLine(data.timestamp, data.message, false);
                    break;
                case 'error':
                    addLine('', '[ERROR] ' + data.message, true, 'error');
                    break;
            }
        }

        function updateStatus(status, port, baudRate) {
            const dot = document.getElementById('statusDot');
            const text = document.getElementById('statusText');
            const portInfo = document.getElementById('portInfo');
            const baudInfo = document.getElementById('baudInfo');
            const connectBtn = document.getElementById('connectBtn');
            const sendBtn = document.getElementById('sendBtn');

            if (status === 'connected') {
                dot.classList.add('connected');
                text.textContent = '已连接';
                portInfo.textContent = port || currentPort;
                baudInfo.textContent = baudRate || currentBaud;
                connectBtn.textContent = '断开';
                connectBtn.classList.remove('connect');
                connectBtn.classList.add('disconnect');
                sendBtn.disabled = false;
            } else {
                dot.classList.remove('connected');
                text.textContent = '未连接';
                portInfo.textContent = '-';
                baudInfo.textContent = '-';
                connectBtn.textContent = '连接';
                connectBtn.classList.remove('disconnect');
                connectBtn.classList.add('connect');
                sendBtn.disabled = true;
            }
        }

        async function refreshPorts() {
            try {
                const res = await fetch('/ports');
                const ports = await res.json();
                const select = document.getElementById('portSelect');
                select.innerHTML = '<option value="">选择串口...</option>';
                ports.forEach(p => {
                    const option = document.createElement('option');
                    option.value = p.path;
                    option.textContent = p.path + (p.manufacturer ? ' (' + p.manufacturer + ')' : '');
                    select.appendChild(option);
                });
            } catch (e) {
                console.error('Failed to refresh ports:', e);
            }
        }

        async function toggleConnect() {
            const btn = document.getElementById('connectBtn');
            if (btn.textContent === '连接') {
                const port = document.getElementById('portSelect').value;
                const baud = parseInt(document.getElementById('baudSelect').value);
                if (!port) {
                    alert('请选择串口');
                    return;
                }
                await fetch('/connect?port=' + port + '&baud=' + baud);
            } else {
                // Disconnect - close and reopen with no port
                if (ws) ws.close();
                location.reload();
            }
        }

        async function sendData() {
            const input = document.getElementById('sendInput');
            const data = input.value;
            if (!data) return;

            try {
                await fetch('/send?data=' + encodeURIComponent(data));
                const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false }) + '.' + Date.now().toString().slice(-3);
                addLine(timestamp, data, true, 'sent');
                input.value = '';
            } catch (e) {
                console.error('Failed to send:', e);
            }
        }

        function handleKeyPress(event) {
            if (event.key === 'Enter') {
                sendData();
            }
        }

        function addLine(timestamp, message, isSent, className) {
            const consoleEl = document.getElementById('console');
            const line = document.createElement('div');
            line.className = 'line' + (className ? ' ' + className : '');

            // Auto-detect message type
            if (!className) {
                const lowerMsg = message.toLowerCase();
                if (lowerMsg.includes('error') || lowerMsg.includes('err')) {
                    line.classList.add('error');
                } else if (lowerMsg.includes('warn')) {
                    line.classList.add('warn');
                } else if (lowerMsg.includes('success') || lowerMsg.includes('ok') || lowerMsg.includes('✅')) {
                    line.classList.add('success');
                } else if (lowerMsg.includes('info')) {
                    line.classList.add('info');
                }
            }

            if (timestamp) {
                line.innerHTML = '<span class="timestamp">[' + timestamp + ']</span>' + escapeHtml(message);
            } else {
                line.innerHTML = escapeHtml(message);
            }

            consoleEl.appendChild(line);
            consoleEl.scrollTop = consoleEl.scrollHeight;

            // Update stats
            lineCount++;
            byteCount += message.length;
            document.getElementById('lineCount').textContent = lineCount;
            document.getElementById('byteCount').textContent = byteCount;

            // Store for log
            logs.push({ timestamp, message, isSent });

            // Limit lines
            while (consoleEl.children.length > 5000) {
                consoleEl.removeChild(consoleEl.firstChild);
            }
        }

        function clearConsole() {
            document.getElementById('console').innerHTML = '';
            lineCount = 0;
            byteCount = 0;
            logs = [];
            document.getElementById('lineCount').textContent = '0';
            document.getElementById('byteCount').textContent = '0';
        }

        function downloadLog() {
            const content = logs.map(l => (l.timestamp ? '[' + l.timestamp + '] ' : '') + (l.isSent ? '[发送] ' : '') + l.message).join('\n');
            const blob = new Blob([content], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'serial_log_' + new Date().toISOString().slice(0, 19).replace(/:/g, '-') + '.txt';
            a.click();
            URL.revokeObjectURL(url);
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Update time
        setInterval(() => {
            document.getElementById('timeDisplay').textContent = new Date().toLocaleTimeString();
        }, 1000);

        // Initialize
        refreshPorts();
        connect();
    </script>
</body>
</html>`;
}

// Initialize with default port
openSerialPort(DEFAULT_PORT, DEFAULT_BAUD);

server.listen(DEFAULT_WEB_PORT, () => {
    console.log(`Starting STM32 Serial Monitor`);
    console.log(`Web UI: http://localhost:${DEFAULT_WEB_PORT}`);
    console.log(`Default port: ${DEFAULT_PORT} @ ${DEFAULT_BAUD}`);
    console.log(`Press Ctrl+C to stop\n`);
});

process.on('SIGINT', () => {
    console.log('\nShutting down...');
    if (serialPort) serialPort.close();
    process.exit();
});