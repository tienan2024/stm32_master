# 🔌 STM32 Serial Monitor 快速开始指南

## 三种使用方式

### 1️⃣ Web UI 模式（推荐，功能最完整）

最新的高性能WebSocket实现：

```powershell
.\monitor_websocket.ps1 -SerialPort "COM3" -BaudRate 115200 -Port 8080
```

**特点：**
- ✅ 高性能 WebSocket 实时通信
- ✅ 美观的Web界面
- ✅ 搜索/过滤功能
- ✅ 日志导出
- ✅ 自动打开浏览器
- ✅ 支持多客户端同时连接

**操作：**
1. 脚本自动打开浏览器访问 `http://localhost:8080/`
2. 看到实时串口数据流
3. 在搜索框输入关键词进行过滤
4. 点击"下载"保存日志文件

---

### 2️⃣ 简化Web模式（备选）

使用HTTP长连接（不需要WebSocket）：

```powershell
.\monitor_web.ps1 -SerialPort "COM3" -BaudRate 115200 -Port 8080
```

**特点：**
- ✅ 轻量级实现
- ✅ Web UI 界面
- ✅ 基本的过滤功能

---

### 3️⃣ 命令行模式（脚本集成）

适合在自动化脚本中使用：

```powershell
# 基本用法
.\monitor_serial.ps1 -Port "COM3" -BaudRate 115200

# 保存日志
.\monitor_serial.ps1 -Port "COM3" -LogFile "debug.log"

# 过滤特定内容（只显示ERROR和WARNING）
.\monitor_serial.ps1 -Port "COM3" -Filter "ERROR|WARNING" -Duration 60

# 自动检测COM端口
.\monitor_serial.ps1 -LogFile "serial.log"
```

**参数说明：**

| 参数 | 说明 | 示例 |
|------|------|------|
| `-Port` | COM端口号 | `COM3`, `COM5` |
| `-BaudRate` | 波特率 | `115200`, `9600` |
| `-LogFile` | 日志文件路径 | `"log.txt"`, `"$PWD\debug.log"` |
| `-Duration` | 运行时长（秒） | `60`, `300` |
| `-Filter` | 正则表达式过滤 | `"ERROR\|FAIL"` |

---

## 常见场景示例

### 场景1：调试固件启动

```powershell
# 启动监控，观察启动日志
.\monitor_websocket.ps1 -SerialPort "COM3"

# 或者用命令行，持续10秒
.\monitor_serial.ps1 -Port "COM3" -Duration 10 -LogFile "startup.log"
```

**预期输出：**
```
[13:45:22.123] ✅ STM32F103 Started!
[13:45:22.234] 📊 System Clock: 72 MHz  
[13:45:22.345] 🔧 Initializing...
[13:45:22.456] ✅ UART initialized @ 115200
```

---

### 场景2：监控实时数据（传感器、GPS等）

```powershell
# 打开Web UI，在搜索框输入过滤条件
.\monitor_websocket.ps1 -SerialPort "COM5"

# 在Web界面搜索框输入: "temperature|humidity"
# 实时显示温湿度数据
```

---

### 场景3：测试中检测错误（CI/CD集成）

```powershell
# 监控30秒，过滤错误信息
.\monitor_serial.ps1 -Port "COM3" `
                    -Duration 30 `
                    -Filter "ERROR|FAIL|Exception" `
                    -LogFile "test_results.log"

# 检查是否有错误
if (Select-String -Path "test_results.log" -Pattern "ERROR" -Quiet) {
    Write-Host "❌ 测试失败"
    exit 1
}
```

---

### 场景4：后台持续监控

```powershell
# 在后台启动，日志持续保存
Start-Process powershell -ArgumentList `
    "-NoProfile -ExecutionPolicy Bypass -File monitor_serial.ps1 -Port COM3 -LogFile data.log" `
    -WindowStyle Hidden

Write-Host "✅ 监控进程已在后台启动"
```

---

## 故障排查

### Q: 无法连接到COM端口？

**检查清单：**
```powershell
# 1. 查看所有可用的COM端口
[System.IO.Ports.SerialPort]::GetPortNames()

# 2. 检查端口是否被占用
# 在设备管理器中查看 "端口(COM和LPT)" 

# 3. 确认波特率正确
# 查看STM32固件或设备文档
```

### Q: Web UI无法打开？

```powershell
# 检查端口是否被占用
netstat -ano | findstr :8080

# 使用不同的端口
.\monitor_websocket.ps1 -Port 9090
```

### Q: 收不到数据？

1. **检查硬件连接：**
   - USB线连接正常
   - 驱动程序已安装

2. **检查固件：**
   ```c
   // STM32固件中确保有串口初始化
   HAL_UART_Init(&huart1);
   printf("Hello\r\n");  // 或使用HAL_UART_Transmit
   ```

3. **检查波特率：**
   ```powershell
   # 尝试不同的波特率
   .\monitor_serial.ps1 -Port "COM3" -BaudRate 9600
   .\monitor_serial.ps1 -Port "COM3" -BaudRate 115200
   ```

---

## Web UI 界面说明

### 顶部工具栏
- 🔌 **连接状态** - 显示当前连接状态
- 📊 **统计信息** - 实时行数和字节数
- 💾 **下载按钮** - 导出日志为CSV文件

### 搜索框
- 支持正则表达式
- 大小写不敏感
- 实时过滤显示

### 消息着色
| 关键词 | 颜色 | 用途 |
|--------|------|------|
| ERROR, ERR | 🔴 红色 | 错误 |
| WARN | 🟠 橙色 | 警告 |
| OK, SUCCESS | 🟢 绿色 | 成功 |
| INFO | 🔵 蓝色 | 信息 |

---

## 实际应用示例

### 例1：STM32+GPS模块调试

```powershell
# 启动监控
.\monitor_websocket.ps1 -SerialPort "COM3" -BaudRate 9600

# 在Web UI中搜索GPS相关信息
# 搜索框输入: "GPRMC|GPGGA"
# 实时查看GPS定位数据
```

### 例2：FreeRTOS任务状态监控

```powershell
.\monitor_serial.ps1 `
    -Port "COM3" `
    -Duration 120 `
    -Filter "Task|Stack|Heap" `
    -LogFile "freertos_monitor.log"

# 分析内存占用趋势
Get-Content "freertos_monitor.log"
```

### 例3：生产测试自动化

```powershell
# 编译和烧录
.\build_flash.ps1 -ProjectDir "."

# 监控测试输出
.\monitor_serial.ps1 `
    -Port "COM3" `
    -Duration 30 `
    -Filter "PASS|FAIL" `
    -LogFile "test_result.log"

# 解析结果
$result = (Select-String -Path "test_result.log" -Pattern "PASS" -Quiet)
if ($result) {
    Write-Host "✅ 测试通过"
} else {
    Write-Host "❌ 测试失败"
}
```

---

## 最佳实践

### 1. 使用Web UI用于交互式调试

```powershell
.\monitor_websocket.ps1 -SerialPort "COM3"
# 实时查看、搜索、过滤数据
```

### 2. 使用命令行用于自动化

```powershell
.\monitor_serial.ps1 -Port "COM3" -Duration 60 -LogFile "log.txt"
# 易于集成到脚本中
```

### 3. 定期保存日志

```powershell
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
.\monitor_serial.ps1 -Port "COM3" -LogFile "logs\$timestamp.log"
```

### 4. 结合其他工具

```powershell
# 同时进行编译和监控
.\build_flash.ps1 -ProjectDir "."
.\monitor_websocket.ps1 -SerialPort "COM3"
```

---

## 技术细节

### 支持的串口参数

- **数据位：** 8 (可配置)
- **停止位：** 1 (可配置)
- **奇偶校验：** None (可配置)
- **流控制：** 无
- **读取超时：** 100-1000ms

### 性能

- **最大连接数：** 无限制（WebSocket）
- **最大日志行数：** 5000行（Web UI中可动态调整）
- **CPU占用：** < 2% (平均)
- **内存占用：** ~ 50-100MB (取决于日志大小)

### 兼容性

- ✅ Windows 7+
- ✅ PowerShell 5.0+
- ✅ .NET Framework 4.5+

---

## 快速快捷方式

### 创建快速启动脚本

**文件：launch_monitor.bat**

```batch
@echo off
REM 快速启动串口监控Web UI
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File monitor_websocket.ps1 -SerialPort "COM3"
pause
```

**使用：** 双击 `launch_monitor.bat` 即可启动

---

## 获取帮助

```powershell
# 查看脚本的完整帮助文档
Get-Help .\monitor_websocket.ps1 -Detailed
Get-Help .\monitor_serial.ps1 -Detailed

# 查看所有参数
Get-Help .\monitor_websocket.ps1 -Full
```

---

## 反馈与改进

如果您有任何问题或建议，欢迎提出！

常见问题：
- 📧 支持多COM端口监控
- 📧 支持波特率自适应
- 📧 增强过滤和统计功能
- 📧 支持数据可视化图表

---

**Happy Debugging! 🎯**
