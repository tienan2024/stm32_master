const SerialPort = require('serialport');
const http = require('http');
const url = require('url');

const PORT = process.argv[3] || 8080;
const SERIAL_PORT = process.argv[2] || 'COM5';
const BAUD_RATE = 115200;

console.log(`Starting STM32 Serial Monitor`);
console.log(`Serial Port: ${SERIAL_PORT} @ ${BAUD_RATE}`);
console.log(`Web UI: http://localhost:${PORT}`);

// Serial port setup
const serialPort = new SerialPort({
    path: SERIAL_PORT,
    baudRate: BAUD_RATE,
    autoOpen: true
});

serialPort.on('open', () => {
    console.log(`\n✅ Connected to ${SERIAL_PORT}`);
    console.log(`📡 Waiting for data...\n`);
});

serialPort.on('data', (data) => {
    const text = data.toString('utf8').trim();
    if (text) {
        const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false }) + '.' + Date.now().toString().slice(-3);
        console.log(`[${timestamp}] ${text}`);
        broadcast(text, timestamp);
    }
});

serialPort.on('error', (err) => {
    console.error(`❌ Serial Error: ${err.message}`);
});

// WebSocket clients
const clients = new Set();

function broadcast(message, timestamp) {
    const data = JSON.stringify({ message, timestamp, type: 'data' });
    clients.forEach(client => {
        try {
            client.send(data);
        } catch (e) {
            clients.delete(client);
        }
    });
}

// Simple Web Server
const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);

    if (parsedUrl.path === '/ws') {
        // WebSocket upgrade
        const protocol = req.headers['upgrade'] === 'websocket' ? 'websocket' : null;
        if (!protocol) {
            res.writeHead(400);
            res.end('Bad Request');
            return;
        }

        // Simple WebSocket handshake
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
        return;
    }

    // HTML page
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(getHtml(SERIAL_PORT, BAUD_RATE));
});

function getHtml(port, baudRate) {
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
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #3c3c3c;
        }
        .header h1 { font-size: 16px; color: #4ec9b0; }
        .status { display: flex; gap: 20px; font-size: 13px; }
        .status-item { display: flex; align-items: center; gap: 5px; }
        .status-dot { width: 8px; height: 8px; border-radius: 50%; background: #f14c4c; }
        .status-dot.connected { background: #4ec9b0; }
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
        .line.error { color: #f14c4c; }
        .line.warn { color: #cca700; }
        .line.success { color: #4ec9b0; }
        .line.info { color: #569cd6; }
        .footer {
            background: #2d2d2d;
            padding: 8px 20px;
            font-size: 12px;
            color: #808080;
            display: flex;
            justify-content: space-between;
        }
        .stats { display: flex; gap: 15px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔌 STM32 Serial Monitor</h1>
        <div class="status">
            <div class="status-item">
                <div class="status-dot" id="statusDot"></div>
                <span id="statusText">Disconnected</span>
            </div>
            <div class="status-item">
                <span>📡</span>
                <span id="portInfo">${port} @ ${baudRate}</span>
            </div>
        </div>
    </div>
    <div class="console" id="console"></div>
    <div class="footer">
        <div class="stats">
            <span>Lines: <span id="lineCount">0</span></span>
            <span>Bytes: <span id="byteCount">0</span></span>
        </div>
        <span>Auto-scroll: ON</span>
    </div>

    <script>
        const consoleEl = document.getElementById('console');
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        const lineCountEl = document.getElementById('lineCount');
        const byteCountEl = document.getElementById('byteCount');

        let lineCount = 0;
        let byteCount = 0;
        let ws;

        function connect() {
            const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            const wsUrl = protocol + '//' + location.host + '/ws?k=random';

            ws = new WebSocket(wsUrl);

            ws.onopen = () => {
                statusDot.classList.add('connected');
                statusText.textContent = 'Connected';
                console.log('WebSocket connected');
            };

            ws.onclose = () => {
                statusDot.classList.remove('connected');
                statusText.textContent = 'Disconnected';
                console.log('WebSocket disconnected, reconnecting...');
                setTimeout(connect, 2000);
            };

            ws.onerror = (err) => {
                console.error('WebSocket error:', err);
            };

            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.type === 'data') {
                        addLine(data.timestamp, data.message);
                    }
                } catch (e) {
                    console.error('Failed to parse message:', e);
                }
            };
        }

        function addLine(timestamp, message) {
            const line = document.createElement('div');
            line.className = 'line';

            // Detect message type
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

            line.innerHTML = '<span class="timestamp">[' + timestamp + ']</span>' + escapeHtml(message);
            consoleEl.appendChild(line);
            consoleEl.scrollTop = consoleEl.scrollHeight;

            lineCount++;
            byteCount += message.length;
            lineCountEl.textContent = lineCount;
            byteCountEl.textContent = byteCount;
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        connect();
    </script>
</body>
</html>`;
}

server.listen(PORT, () => {
    console.log(`🌐 Web UI available at http://localhost:${PORT}`);
    console.log(`   Press Ctrl+C to stop\n`);
});

process.on('SIGINT', () => {
    console.log('\n\nShutting down...');
    serialPort.close();
    process.exit();
});