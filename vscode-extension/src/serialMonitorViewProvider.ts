import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { SerialPortManager } from './serialPortManager';

export class SerialMonitorViewProvider implements vscode.WebviewViewProvider {
    private webviewView?: vscode.WebviewView;
    private extensionUri: vscode.Uri;
    private serialPortManager: SerialPortManager;
    private isMonitoring: boolean = false;
    private logBuffer: Array<{ timestamp: string; message: string }> = [];
    private totalBytes: number = 0;

    constructor(extensionUri: vscode.Uri, serialPortManager: SerialPortManager) {
        this.extensionUri = extensionUri;
        this.serialPortManager = serialPortManager;

        // 监听串口管理器的事件
        this.serialPortManager.on('data', (line: string) => {
            this.handleSerialData(line);
        });

        this.serialPortManager.on('error', (error: string) => {
            this.showError(error);
        });

        this.serialPortManager.on('portClosed', () => {
            this.isMonitoring = false;
            this.updateStatus('disconnected');
        });
    }

    async resolveWebviewView(
        webviewView: vscode.WebviewView,
        context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken
    ): Promise<void> {
        this.webviewView = webviewView;

        // 设置WebView选项
        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this.extensionUri]
        };

        // 生成HTML内容
        webviewView.webview.html = this.getWebviewContent(webviewView.webview);

        // 处理从WebView发送的消息
        webviewView.webview.onDidReceiveMessage((message) => {
            this.handleWebviewMessage(message);
        });
    }

    async startMonitoring(): Promise<void> {
        const config = vscode.workspace.getConfiguration('stm32.serialMonitor');
        let port = config.get<string>('port');
        let baudRate = config.get<number>('baudRate') || 115200;
        const dataBits = config.get<number>('dataBits') || 8;
        const stopBits = config.get<number>('stopBits') || 1;
        const parity = config.get<string>('parity') as 'none' | 'odd' | 'even' || 'none';

        if (!port) {
            vscode.window.showErrorMessage('Please select a COM port first');
            return;
        }

        const success = await this.serialPortManager.openPort(port, baudRate, dataBits, stopBits, parity);

        if (success) {
            this.isMonitoring = true;
            this.logBuffer = [];
            this.totalBytes = 0;
            this.updateStatus('connected');
            vscode.window.showInformationMessage(`Connected to ${port} @ ${baudRate}`);
        }
    }

    async stopMonitoring(): Promise<void> {
        this.serialPortManager.closePort();
        this.isMonitoring = false;
        this.updateStatus('disconnected');
        vscode.window.showInformationMessage('Monitoring stopped');
    }

    clearOutput(): void {
        this.logBuffer = [];
        this.totalBytes = 0;
        this.sendMessage({
            command: 'clear'
        });
    }

    downloadLog(): void {
        if (this.logBuffer.length === 0) {
            vscode.window.showWarningMessage('No data to download');
            return;
        }

        const logText = this.logBuffer
            .map(l => `[${l.timestamp}] ${l.message}`)
            .join('\n');

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const fileName = `serial_${timestamp}.log`;

        vscode.window.showSaveDialog({
            defaultUri: vscode.Uri.file(fileName),
            filters: {
                'Log files': ['log'],
                'Text files': ['txt']
            }
        }).then(fileUri => {
            if (fileUri) {
                fs.writeFileSync(fileUri.fsPath, logText, 'utf8');
                vscode.window.showInformationMessage(`Log saved to ${fileUri.fsPath}`);
            }
        });
    }

    updatePortInfo(): void {
        const config = vscode.workspace.getConfiguration('stm32.serialMonitor');
        const port = config.get<string>('port');
        const baudRate = config.get<number>('baudRate') || 115200;

        this.sendMessage({
            command: 'updatePortInfo',
            port: port || 'Not selected',
            baudRate
        });
    }

    private handleSerialData(line: string): void {
        const timestamp = new Date().toLocaleTimeString('zh-CN', {
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }) + '.' + new Date().getMilliseconds().toString().padStart(3, '0');

        const entry = { timestamp, message: line };
        this.logBuffer.push(entry);
        this.totalBytes += line.length + 1;

        // 限制缓冲区大小
        const maxLines = vscode.workspace.getConfiguration('stm32.serialMonitor').get<number>('maxLines') || 5000;
        if (this.logBuffer.length > maxLines) {
            this.logBuffer.shift();
        }

        this.sendMessage({
            command: 'addLine',
            timestamp,
            message: line,
            totalLines: this.logBuffer.length,
            totalBytes: this.formatBytes(this.totalBytes)
        });
    }

    private handleWebviewMessage(message: any): void {
        const { command } = message;

        switch (command) {
            case 'getConfig':
                const config = vscode.workspace.getConfiguration('stm32.serialMonitor');
                this.sendMessage({
                    command: 'config',
                    port: config.get<string>('port') || '',
                    baudRate: config.get<number>('baudRate') || 115200,
                    isConnected: this.serialPortManager.isConnected(),
                    totalLines: this.logBuffer.length,
                    totalBytes: this.formatBytes(this.totalBytes)
                });
                break;

            case 'refreshPorts':
                this.refreshPortList();
                break;

            case 'selectPort':
                this.refreshPortList();
                break;

            case 'filter':
                const { filterText } = message;
                const filtered = this.logBuffer.filter(l =>
                    new RegExp(filterText, 'i').test(l.message)
                );
                this.sendMessage({
                    command: 'filteredLines',
                    lines: filtered
                });
                break;

            case 'export':
                this.downloadLog();
                break;

            case 'setPort':
                this.setPort(message.port, message.baudRate);
                break;
        }
    }

    public async refreshPortList(): Promise<void> {
        const ports = await this.serialPortManager.listPorts();
        this.sendMessage({
            command: 'portList',
            ports: ports.map(p => p.path)
        });
    }

    private async setPort(port: string, baudRate: number): Promise<void> {
        const config = vscode.workspace.getConfiguration('stm32.serialMonitor');
        await config.update('port', port, vscode.ConfigurationTarget.Global);
        await config.update('baudRate', baudRate, vscode.ConfigurationTarget.Global);
        this.sendMessage({
            command: 'config',
            port: port,
            baudRate: baudRate,
            isConnected: this.serialPortManager.isConnected(),
            totalLines: this.logBuffer.length,
            totalBytes: this.formatBytes(this.totalBytes)
        });
    }

    private sendMessage(message: any): void {
        if (this.webviewView) {
            this.webviewView.webview.postMessage(message);
        }
    }

    private updateStatus(status: 'connected' | 'disconnected' | 'error'): void {
        this.sendMessage({
            command: 'updateStatus',
            status,
            port: this.serialPortManager.getPortPath()
        });
    }

    private showError(error: string): void {
        this.sendMessage({
            command: 'error',
            message: error
        });
    }

    private formatBytes(bytes: number): string {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
    }

    private getWebviewContent(webview: vscode.Webview): string {
        const styleUri = webview.asWebviewUri(
            vscode.Uri.joinPath(this.extensionUri, 'media', 'style.css')
        );
        const scriptUri = webview.asWebviewUri(
            vscode.Uri.joinPath(this.extensionUri, 'media', 'script.js')
        );

        const nonce = this.getNonce();

        return `
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src ${webview.cspSource} 'unsafe-inline'; script-src 'nonce-${nonce}';">
                <title>STM32 Serial Monitor</title>
                <link rel="stylesheet" href="${styleUri}">
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h2>🔌 Serial Monitor</h2>
                        <div class="status-indicator" id="statusIndicator">
                            <div class="status-dot"></div>
                            <span id="statusText">Offline</span>
                        </div>
                    </div>

                    <div class="port-selector">
                        <select id="portSelect" class="select-input">
                            <option value="">Select COM Port...</option>
                        </select>
                        <select id="baudRateSelect" class="select-input">
                            <option value="9600">9600</option>
                            <option value="19200">19200</option>
                            <option value="38400">38400</option>
                            <option value="57600">57600</option>
                            <option value="115200" selected>115200</option>
                            <option value="230400">230400</option>
                            <option value="460800">460800</option>
                            <option value="921600">921600</option>
                        </select>
                    </div>

                    <div class="controls">
                        <button id="startBtn" class="btn btn-primary">Start</button>
                        <button id="stopBtn" class="btn btn-danger" disabled>Stop</button>
                        <button id="clearBtn" class="btn btn-secondary">Clear</button>
                        <button id="exportBtn" class="btn btn-secondary">Export</button>
                        <button id="refreshBtn" class="btn btn-small">🔄</button>
                    </div>

                    <div class="search-box">
                        <input type="text" id="filterInput" placeholder="🔍 Filter (regex)...">
                        <button id="filterBtn" class="btn btn-small">Filter</button>
                        <button id="clearFilterBtn" class="btn btn-small">Clear</button>
                    </div>

                    <div class="stats">
                        <span>Lines: <span id="lineCount">0</span></span>
                        <span>Bytes: <span id="byteCount">0 B</span></span>
                    </div>

                    <div class="console" id="console"></div>

                    <div class="footer">
                        STM32 Serial Monitor • Real-time output
                    </div>
                </div>

                <script nonce="${nonce}" src="${scriptUri}"></script>
            </body>
            </html>
        `;
    }

    private getNonce(): string {
        let text = '';
        const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        for (let i = 0; i < 32; i++) {
            text += possible.charAt(Math.floor(Math.random() * possible.length));
        }
        return text;
    }
}
