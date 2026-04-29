import * as vscode from 'vscode';
import { SerialMonitorViewProvider } from './serialMonitorViewProvider';
import { SerialPortManager } from './serialPortManager';

let serialMonitorProvider: SerialMonitorViewProvider;
let serialPortManager: SerialPortManager;

export function activate(context: vscode.ExtensionContext) {
    console.log('🔌 STM32 Serial Monitor Extension activated');

    // 初始化串口管理器
    serialPortManager = new SerialPortManager();

    // 创建WebView视图提供者
    serialMonitorProvider = new SerialMonitorViewProvider(context.extensionUri, serialPortManager);

    // 注册WebView视图提供者
    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(
            'serialMonitorView',
            serialMonitorProvider,
            {
                webviewOptions: {
                    retainContextWhenHidden: true
                }
            }
        )
    );

    // 注册命令
    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.open', () => {
            vscode.commands.executeCommand('serialMonitorView.focus');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.startMonitoring', async () => {
            try {
                await serialMonitorProvider.startMonitoring();
            } catch (error) {
                vscode.window.showErrorMessage(`Failed to start monitoring: ${error}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.stopMonitoring', async () => {
            try {
                await serialMonitorProvider.stopMonitoring();
            } catch (error) {
                vscode.window.showErrorMessage(`Failed to stop monitoring: ${error}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.clearOutput', () => {
            serialMonitorProvider.clearOutput();
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.downloadLog', () => {
            serialMonitorProvider.downloadLog();
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.selectPort', async () => {
            const ports = await serialPortManager.listPorts();

            if (ports.length === 0) {
                vscode.window.showErrorMessage('No COM ports found');
                return;
            }

            const selected = await vscode.window.showQuickPick(
                ports.map(p => ({ label: p.path, description: (p as any).friendlyName || p.manufacturer || '' })),
                { placeHolder: 'Select COM port' }
            );

            if (selected) {
                const config = vscode.workspace.getConfiguration('stm32.serialMonitor');
                await config.update('port', selected.label, vscode.ConfigurationTarget.Global);
                vscode.window.showInformationMessage(`COM port set to ${selected.label}`);
                serialMonitorProvider.updatePortInfo();
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stm32-serial-monitor.refreshPorts', async () => {
            serialMonitorProvider.refreshPortList();
        })
    );

    vscode.window.showInformationMessage('✅ STM32 Serial Monitor is ready!');
}

export function deactivate() {
    if (serialPortManager) {
        serialPortManager.closePort();
    }
    console.log('🔌 STM32 Serial Monitor Extension deactivated');
}
