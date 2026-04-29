// Get VS Code API
const vscode = acquireVsCodeApi();

// DOM Elements
const startBtn = document.getElementById('startBtn');
const stopBtn = document.getElementById('stopBtn');
const clearBtn = document.getElementById('clearBtn');
const exportBtn = document.getElementById('exportBtn');
const refreshBtn = document.getElementById('refreshBtn');
const consoleEl = document.getElementById('console');
const filterInput = document.getElementById('filterInput');
const filterBtn = document.getElementById('filterBtn');
const clearFilterBtn = document.getElementById('clearFilterBtn');
const statusIndicator = document.querySelector('.status-dot');
const statusText = document.getElementById('statusText');
const portSelect = document.getElementById('portSelect');
const baudRateSelect = document.getElementById('baudRateSelect');
const lineCount = document.getElementById('lineCount');
const byteCount = document.getElementById('byteCount');

let isMonitoring = false;
let allLines = [];
let filterRegex = null;

// Initialize
window.addEventListener('load', () => {
    vscode.postMessage({ command: 'getConfig' });
    vscode.postMessage({ command: 'refreshPorts' });
});

// Event Listeners
startBtn.addEventListener('click', () => {
    const port = portSelect.value;
    const baudRate = parseInt(baudRateSelect.value);
    if (!port) {
        alert('Please select a COM port');
        return;
    }
    vscode.postMessage({ command: 'setPort', port, baudRate });
    setTimeout(() => {
        vscode.postMessage({ command: 'startMonitoring' });
    }, 100);
});

stopBtn.addEventListener('click', () => {
    vscode.postMessage({ command: 'stopMonitoring' });
});

clearBtn.addEventListener('click', () => {
    consoleEl.innerHTML = '<div class="empty-state"><div class="empty-state-icon">✨</div><div>Cleared</div></div>';
    allLines = [];
    vscode.postMessage({ command: 'clearOutput' });
});

exportBtn.addEventListener('click', () => {
    vscode.postMessage({ command: 'export' });
});

refreshBtn.addEventListener('click', () => {
    vscode.postMessage({ command: 'refreshPorts' });
});

portSelect.addEventListener('change', () => {
    if (portSelect.value) {
        const baudRate = parseInt(baudRateSelect.value);
        vscode.postMessage({ command: 'setPort', port: portSelect.value, baudRate });
    }
});

baudRateSelect.addEventListener('change', () => {
    if (portSelect.value) {
        const baudRate = parseInt(baudRateSelect.value);
        vscode.postMessage({ command: 'setPort', port: portSelect.value, baudRate });
    }
});

filterBtn.addEventListener('click', applyFilter);
clearFilterBtn.addEventListener('click', clearFilter);

filterInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        applyFilter();
    }
});

// Apply Filter
function applyFilter() {
    const filterText = filterInput.value.trim();
    if (!filterText) {
        clearFilter();
        return;
    }

    try {
        filterRegex = new RegExp(filterText, 'i');
    } catch (error) {
        alert('Invalid regex: ' + error.message);
        return;
    }

    renderConsole();
}

// Clear Filter
function clearFilter() {
    filterInput.value = '';
    filterRegex = null;
    renderConsole();
}

// Render Console
function renderConsole() {
    consoleEl.innerHTML = '';

    if (allLines.length === 0) {
        consoleEl.innerHTML = '<div class="empty-state"><div class="empty-state-icon">⏳</div><div>Waiting for data...</div></div>';
        return;
    }

    const linesToShow = filterRegex
        ? allLines.filter(l => filterRegex.test(l.message))
        : allLines;

    if (linesToShow.length === 0 && filterRegex) {
        consoleEl.innerHTML = '<div class="empty-state"><div class="empty-state-icon">🔍</div><div>No matching lines</div></div>';
        return;
    }

    linesToShow.forEach(line => {
        renderLine(line.timestamp, line.message);
    });

    // Auto scroll to bottom
    const autoScroll = vscode.getState()?.autoScroll !== false;
    if (autoScroll) {
        consoleEl.scrollTop = consoleEl.scrollHeight;
    }
}

// Render Single Line
function renderLine(timestamp, message) {
    const lineDiv = document.createElement('div');
    lineDiv.className = 'console-line';

    const timeSpan = document.createElement('span');
    timeSpan.className = 'timestamp';
    timeSpan.textContent = `[${timestamp}]`;

    const msgSpan = document.createElement('span');
    msgSpan.className = 'message';
    msgSpan.textContent = message;

    // Detect message type
    if (/error|ERROR|ERR|✗/i.test(message)) {
        msgSpan.classList.add('error');
    } else if (/warning|WARN|warn|⚠/i.test(message)) {
        msgSpan.classList.add('warn');
    } else if (/success|OK|✓|✅/i.test(message)) {
        msgSpan.classList.add('success');
    } else if (/info|INFO|ℹ/i.test(message)) {
        msgSpan.classList.add('info');
    } else if (/debug|DEBUG|DBG/i.test(message)) {
        msgSpan.classList.add('debug');
    }

    lineDiv.appendChild(timeSpan);
    lineDiv.appendChild(msgSpan);
    consoleEl.appendChild(lineDiv);
}

// Update Status
function updateStatus(status, port) {
    statusIndicator.className = 'status-dot';

    switch (status) {
        case 'connected':
            statusIndicator.classList.add('connected');
            statusText.textContent = 'Connected';
            startBtn.disabled = true;
            stopBtn.disabled = false;
            portSelect.disabled = true;
            baudRateSelect.disabled = true;
            break;

        case 'disconnected':
            statusText.textContent = 'Offline';
            startBtn.disabled = false;
            stopBtn.disabled = true;
            portSelect.disabled = false;
            baudRateSelect.disabled = false;
            break;

        case 'error':
            statusIndicator.classList.add('error');
            statusText.textContent = 'Error';
            startBtn.disabled = false;
            stopBtn.disabled = true;
            portSelect.disabled = false;
            baudRateSelect.disabled = false;
            break;
    }
}

// Message Handler from Extension
window.addEventListener('message', event => {
    const message = event.data;

    switch (message.command) {
        case 'config':
            // Set port select value
            if (message.port) {
                portSelect.value = message.port;
            }
            // Set baud rate select value
            baudRateSelect.value = message.baudRate.toString();
            lineCount.textContent = message.totalLines;
            byteCount.textContent = message.totalBytes;
            updateStatus(message.isConnected ? 'connected' : 'disconnected');
            break;

        case 'portList':
            const currentPort = portSelect.value;
            portSelect.innerHTML = '<option value="">Select COM Port...</option>';
            message.ports.forEach(port => {
                const option = document.createElement('option');
                option.value = port;
                option.textContent = port;
                portSelect.appendChild(option);
            });
            if (currentPort && message.ports.includes(currentPort)) {
                portSelect.value = currentPort;
            }
            break;

        case 'addLine':
            allLines.push({
                timestamp: message.timestamp,
                message: message.message
            });
            lineCount.textContent = message.totalLines;
            byteCount.textContent = message.totalBytes;

            if (!filterRegex || filterRegex.test(message.message)) {
                renderLine(message.timestamp, message.message);
                const autoScroll = vscode.getState()?.autoScroll !== false;
                if (autoScroll) {
                    consoleEl.scrollTop = consoleEl.scrollHeight;
                }
            }
            break;

        case 'clear':
            consoleEl.innerHTML = '<div class="empty-state"><div class="empty-state-icon">✨</div><div>Cleared</div></div>';
            break;

        case 'filteredLines':
            renderConsole();
            break;

        case 'updateStatus':
            updateStatus(message.status, message.port);
            break;

        case 'updatePortInfo':
            portSelect.value = message.port;
            baudRateSelect.value = message.baudRate.toString();
            break;

        case 'error':
            alert('Error: ' + message.message);
            updateStatus('error');
            break;
    }
});

// Save State
window.addEventListener('beforeunload', () => {
    vscode.setState({ autoScroll: true });
});

// Initial render
renderConsole();
