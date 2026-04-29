// @ts-ignore - types mismatch with actual serialport@9 API
const SerialPort = require('serialport');
import { EventEmitter } from 'events';

export class SerialPortManager extends EventEmitter {
    private port: any = null;
    private lineBuffer: string = '';

    async listPorts(): Promise<any[]> {
        try {
            // @ts-ignore
            const ports = await SerialPort.list();
            return ports;
        } catch (error) {
            console.error('Error listing ports:', error);
            return [];
        }
    }

    async openPort(
        portPath: string,
        baudRate: number = 115200,
        dataBits: number = 8,
        stopBits: number = 1,
        parity: 'none' | 'odd' | 'even' = 'none'
    ): Promise<boolean> {
        try {
            if (this.port && this.port.isOpen) {
                this.port.close();
            }

            // @ts-ignore
            this.port = new SerialPort({
                path: portPath,
                baudRate,
                dataBits,
                stopBits,
                parity,
                autoOpen: true
            });

            this.port.on('data', (data: Buffer) => {
                this.handleData(data);
            });

            this.port.on('error', (error: Error) => {
                console.error('Serial port error:', error);
                this.emit('error', error.message);
            });

            this.port.on('close', () => {
                this.emit('portClosed');
            });

            this.port.on('open', () => {
                this.emit('portOpened');
            });

            return true;
        } catch (error) {
            console.error('Failed to open port:', error);
            this.emit('error', `Failed to open port ${portPath}: ${error}`);
            return false;
        }
    }

    closePort(): void {
        if (this.port && this.port.isOpen) {
            this.port.close();
        }
    }

    private handleData(data: Buffer): void {
        const text = data.toString('utf8');
        
        for (const char of text) {
            if (char === '\n') {
                const line = this.lineBuffer.trimEnd();
                this.lineBuffer = '';
                
                if (line) {
                    this.emit('data', line);
                }
            } else if (char !== '\r') {
                this.lineBuffer += char;
            }
        }
    }

    isConnected(): boolean {
        return this.port !== null && this.port.isOpen;
    }

    getPortPath(): string {
        return this.port?.path || '';
    }
}
