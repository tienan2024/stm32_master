# 🔌 STM32 Serial Monitor - 项目总结

本项目为 STM32 嵌入式开发添加了**实时串口监控功能**，包括三种使用方式：

## 📋 项目结构

```
stm32_master/
├── monitor_serial.ps1            # 命令行监控脚本
├── monitor_web.ps1               # Web UI 监控脚本
├── monitor_websocket.ps1         # WebSocket 高性能监控
├── MONITOR_QUICKSTART.md          # 快速开始指南
│
├── vscode-extension/              # VS Code 扩展（推荐）
│   ├── src/
│   │   ├── extension.ts           # 扩展主文件
│   │   ├── serialPortManager.ts   # 串口管理
│   │   └── serialMonitorViewProvider.ts  # WebView提供者
│   ├── media/
│   │   ├── style.css              # 样式表
│   │   └── script.js              # 前端逻辑
│   ├── package.json               # 扩展配置
│   ├── setup.bat                  # Windows 自动安装脚本
│   ├── INSTALL.md                 # 安装指南
│   └── README.md                  # 扩展文档
│
└── README.md                      # 项目说明
```

## 🚀 三种使用方式

### 1️⃣ VS Code 扩展（推荐 ⭐⭐⭐⭐⭐）

**优点：**
- ✅ 集成在编辑器中，无需切换窗口
- ✅ VS Code主题自动适配
- ✅ 完整的功能集
- ✅ 持久化配置
- ✅ 自动检测COM端口

**安装：**
```powershell
cd vscode-extension
setup.bat
```

**使用：**
- 左侧活动栏点击串口图标
- 选择COM端口 → 开始监控

**快捷命令：**
- `Ctrl+Shift+P` → 输入 "STM32"

### 2️⃣ Web UI 模式（备选 ⭐⭐⭐⭐）

**优点：**
- ✅ 独立浏览器界面
- ✅ 美观的Web设计
- ✅ 支持多客户端连接
- ✅ 易于远程访问

**使用：**
```powershell
.\monitor_websocket.ps1 -SerialPort "COM3" -Port 8080
# 自动打开浏览器
```

**访问：** http://localhost:8080/

### 3️⃣ 命令行模式（脚本集成 ⭐⭐⭐）

**优点：**
- ✅ 轻量级
- ✅ 易于脚本集成
- ✅ 支持CI/CD
- ✅ 日志文件导出

**使用：**
```powershell
.\monitor_serial.ps1 -Port "COM3" -LogFile "debug.log"
```

---

## 🎯 快速开始

### 步骤1：安装VS Code扩展

```powershell
cd vscode-extension
setup.bat
```

### 步骤2：重启VS Code

关闭并重新打开VS Code

### 步骤3：打开Serial Monitor

- 点击左侧活动栏的串口图标
- 或按 `Ctrl+Shift+P` 搜索 "Open Serial Monitor"

### 步骤4：选择COM端口

点击"Select"按钮，从列表中选择

### 步骤5：启动监控

点击"Start"按钮开始实时监控

---

## 📊 功能对比

| 功能 | VS Code | Web UI | 命令行 |
|------|--------|--------|--------|
| 实时显示 | ✅ | ✅ | ✅ |
| 搜索过滤 | ✅ | ✅ | ✅ |
| 日志导出 | ✅ | ✅ | ✅ |
| 智能着色 | ✅ | ✅ | ❌ |
| 自动检测 | ✅ | ✅ | ❌ |
| 编辑器集成 | ✅ | ❌ | ❌ |
| 脚本集成 | ❌ | ❌ | ✅ |
| 多客户端 | ❌ | ✅ | ❌ |
| 配置持久化 | ✅ | ❌ | ❌ |

---

## 🔧 配置选项

### VS Code 设置

在 `settings.json` 中配置：

```json
{
    "stm32.serialMonitor.port": "COM3",
    "stm32.serialMonitor.baudRate": 115200,
    "stm32.serialMonitor.dataBits": 8,
    "stm32.serialMonitor.stopBits": 1,
    "stm32.serialMonitor.parity": "none",
    "stm32.serialMonitor.autoScroll": true,
    "stm32.serialMonitor.maxLines": 5000
}
```

### 命令行参数

```powershell
# 监控脚本参数
.\monitor_serial.ps1 `
    -Port "COM3" `                  # COM端口
    -BaudRate 115200 `              # 波特率
    -LogFile "debug.log" `          # 日志文件
    -Duration 60 `                  # 运行时长（秒）
    -Filter "ERROR|WARNING"         # 正则表达式过滤
```

---

## 🎨 消息着色（智能识别）

| 关键词 | 颜色 | 用途 |
|--------|------|------|
| ERROR, ERR, ✗ | 🔴 红色 | 错误信息 |
| WARN, WARNING | 🟠 橙色 | 警告信息 |
| OK, SUCCESS, ✅ | 🟢 青色 | 成功信息 |
| INFO, ℹ️ | 🔵 蓝色 | 信息提示 |
| DEBUG, DBG | 灰色 | 调试信息 |

---

## 💡 使用场景

### 场景1：固件开发调试

```powershell
# 启动监控观察启动日志
.\monitor_websocket.ps1 -SerialPort "COM3"

# 在输出中查看：
# [13:45:22.123] ✅ STM32 Started!
# [13:45:22.456] 🔧 Initializing...
# [13:45:22.789] ✅ Ready
```

### 场景2：实时数据监控

```powershell
# 在VS Code中监控传感器数据
# 在搜索框输入: "temperature|humidity"
# 实时看到温湿度数据
```

### 场景3：生产测试自动化

```powershell
# 编译和烧录
.\build_flash.ps1 -ProjectDir "."

# 监控测试输出
.\monitor_serial.ps1 `
    -Port "COM3" `
    -Duration 30 `
    -Filter "PASS|FAIL" `
    -LogFile "test_result.log"

# 检查结果
if (Select-String -Path "test_result.log" -Pattern "FAIL") {
    Write-Host "❌ 测试失败"
} else {
    Write-Host "✅ 测试通过"
}
```

### 场景4：远程开发

```powershell
# 启动Web UI，通过网络访问
.\monitor_websocket.ps1 -SerialPort "COM3" -Port 8080

# 在另一台电脑访问
# http://<IP>:8080/
```

---

## 🐛 故障排查

### 无法找到COM端口

```powershell
# 检查设备连接
[System.IO.Ports.SerialPort]::GetPortNames()

# 检查驱动程序（Windows）
# 设备管理器 > 端口(COM和LPT)
```

### 收不到数据

1. ✅ 确认USB连接正常
2. ✅ 检查波特率与固件一致
3. ✅ 确认STM32固件初始化了UART
4. ✅ 检查驱动程序是否安装

### VS Code扩展不显示

```bash
# 检查是否安装
code --list-extensions | findstr stm32

# 重新安装
vsce package
code --install-extension stm32-serial-monitor-*.vsix --force
```

---

## 📚 文档导航

- 📖 [VS Code 扩展安装指南](vscode-extension/INSTALL.md)
- 📖 [VS Code 扩展说明](vscode-extension/README.md)
- 📖 [命令行快速开始](MONITOR_QUICKSTART.md)
- 📖 [主SKILL文档](SKILL.md)

---

## 🔧 开发和贡献

### 修改VS Code扩展

```bash
cd vscode-extension

# 开发模式
code .
# 按 F5 启动调试

# 编译
npm run compile

# 打包
vsce package

# 安装
code --install-extension stm32-serial-monitor-*.vsix
```

### 改进建议

欢迎提交改进建议：
- 多COM端口同时监控
- 数据可视化图表
- 性能优化
- 国际化支持

---

## 📊 项目统计

| 指标 | 值 |
|------|-----|
| 脚本文件 | 3个 (PowerShell) |
| VS Code扩展 | TypeScript + HTML + CSS |
| 代码行数 | ~3000+ |
| 支持的OS | Windows, Mac, Linux |
| 最小依赖 | Node.js 14+, VS Code 1.70+ |

---

## 🎓 学习资源

### 串口通信基础

- 波特率：通常 9600 或 115200
- 数据格式：8N1 (8位数据、无奇偶校验、1停止位)
- 最大速率：115200 baud

### STM32 UART 初始化示例

```c
// 使用HAL库
MX_UART1_Init();  // 自动生成的初始化函数

// 发送数据
HAL_UART_Transmit(&huart1, (uint8_t*)"Hello\r\n", 7, 100);

// 使用printf
#include <stdio.h>
printf("Value: %d\r\n", value);
```

---

## 📝 许可证

MIT License - 自由使用和修改

---

## 🎉 致谢

感谢使用STM32 Serial Monitor！

如有问题或建议，欢迎反馈。

**祝开发愉快！🚀**

---

## 快速命令参考

```powershell
# VS Code 扩展安装
cd vscode-extension
setup.bat

# Web UI 启动
.\monitor_websocket.ps1 -SerialPort "COM3"

# 命令行监控
.\monitor_serial.ps1 -Port "COM3" -LogFile "log.txt"

# 查看所有COM端口
[System.IO.Ports.SerialPort]::GetPortNames()

# VS Code 命令
Ctrl+Shift+P → STM32: Start Monitoring
```

---

**版本信息：** v1.0.0 | 更新于 2026年4月
