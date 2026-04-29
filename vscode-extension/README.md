# STM32 Serial Monitor VS Code Extension

实时串口监控VS Code扩展，集成在VS Code侧边栏中。

## 功能特性

✨ **核心功能：**
- 🔌 实时读取STM32设备串口数据
- 📊 在VS Code侧边栏显示数据流
- 🔍 支持正则表达式过滤
- 🎨 智能着色（ERROR/WARN/SUCCESS等）
- 📥 导出日志文件
- 💾 自动滚动到最新数据
- ⚙️ 可配置的波特率和串口参数

## 系统要求

- **VS Code** 1.70.0 或更高版本
- **Node.js** 14.0 或更高版本
- **Windows/Mac/Linux** 操作系统

## 安装

### 方式1：从源代码构建

```bash
# 克隆或下载此目录
cd vscode-extension

# 安装依赖
npm install

# 编译TypeScript
npm run compile

# 打包VSIX文件
npm run package
# （需要安装 vsce: npm install -g @vscode/vsce）

# 在VS Code中安装VSIX
code --install-extension stm32-serial-monitor-1.0.0.vsix
```

### 方式2：直接运行（开发模式）

```bash
# 打开扩展文件夹
code vscode-extension

# 按 F5 启动调试
# VS Code 会打开一个新窗口，加载此扩展

# 修改代码后，在新窗口中按 Ctrl+R 重新加载
```

## 快速开始

### 1. 选择COM端口

- 打开VS Code的"STM32 Serial Monitor"视图
- 点击"Select"按钮
- 从列表中选择STM32连接的COM端口

### 2. 启动监控

- 点击"Start"按钮
- 实时查看STM32的串口输出

### 3. 使用过滤

- 在搜索框输入正则表达式（如 `ERROR|WARNING`）
- 点击"Filter"只显示匹配的行

### 4. 导出日志

- 点击"Export"按钮
- 选择文件保存位置
- 日志文件包含时间戳和完整输出

## 配置选项

VS Code设置中可配置的选项：

```json
{
    "stm32.serialMonitor.port": "COM3",           // COM端口
    "stm32.serialMonitor.baudRate": 115200,      // 波特率
    "stm32.serialMonitor.dataBits": 8,            // 数据位
    "stm32.serialMonitor.stopBits": 1,            // 停止位
    "stm32.serialMonitor.parity": "none",         // 奇偶校验
    "stm32.serialMonitor.autoScroll": true,       // 自动滚动
    "stm32.serialMonitor.maxLines": 5000          // 最大缓冲行数
}
```

### 在settings.json中配置

```json
{
    "stm32.serialMonitor.port": "COM3",
    "stm32.serialMonitor.baudRate": 9600,
    "stm32.serialMonitor.autoScroll": true
}
```

## 使用方式

### 侧边栏视图

1. **连接指示器** - 显示当前连接状态
2. **端口选择** - 显示已选择的COM端口和波特率
3. **控制按钮** - Start/Stop/Clear/Export
4. **搜索过滤** - 支持正则表达式的过滤
5. **统计信息** - 显示总行数和字节数
6. **数据面板** - 实时显示串口数据

### 快捷命令

打开命令面板 (Ctrl+Shift+P) 并输入：

```
STM32: Open Serial Monitor      # 打开监控视图
STM32: Start Monitoring         # 启动监控
STM32: Stop Monitoring          # 停止监控
STM32: Clear Output             # 清空输出
STM32: Download Log             # 下载日志
STM32: Select COM Port          # 选择COM端口
```

## 消息着色

自动识别并着色：

| 关键词 | 颜色 | 用途 |
|--------|------|------|
| ERROR, ERR, ✗ | 🔴 红色 | 错误信息 |
| WARNING, WARN | 🟠 橙色 | 警告信息 |
| SUCCESS, OK, ✅ | 🟢 青色 | 成功信息 |
| INFO, ℹ️ | 🔵 蓝色 | 信息提示 |
| DEBUG, DBG | 灰色 | 调试信息 |

## 故障排查

### 问题：无法找到COM端口

**解决方案：**
1. 检查USB连接是否正常
2. 在设备管理器中检查COM端口
3. 确认STM32驱动已安装
4. 尝试在资源管理器中重新扫描

```powershell
# 在PowerShell中列出所有COM端口
[System.IO.Ports.SerialPort]::GetPortNames()
```

### 问题：收不到数据

**检查清单：**
1. ✅ 确认已点击"Start"按钮
2. ✅ 确认波特率与固件设置相同
3. ✅ 确认STM32固件正确配置了UART
4. ✅ 检查USB连接和驱动

### 问题：过滤不工作

**解决方案：**
- 确保使用了有效的正则表达式
- 示例：
  - `ERROR` - 匹配包含ERROR的行
  - `ERROR|WARN` - 匹配ERROR或WARN
  - `^\[.*\]` - 匹配以[开头的行

### 问题：扩展未加载

**解决方案：**
```bash
# 检查扩展日志
code --user-data-dir=. --log=error

# 或在开发模式下调试 (F5)
```

## 文件结构

```
vscode-extension/
├── src/
│   ├── extension.ts                 # 扩展主入口
│   ├── serialPortManager.ts         # 串口管理类
│   └── serialMonitorViewProvider.ts # WebView提供者
├── media/
│   ├── style.css                    # 样式表
│   └── script.js                    # 前端逻辑
├── package.json                     # 扩展配置
├── tsconfig.json                    # TypeScript配置
└── README.md                        # 本文件
```

## 开发指南

### 本地开发

1. **克隆和安装依赖：**
   ```bash
   cd vscode-extension
   npm install
   ```

2. **编译TypeScript：**
   ```bash
   npm run compile
   ```

3. **开启监听模式：**
   ```bash
   npm run watch
   ```

4. **调试扩展：**
   - 按 F5 在新的VS Code窗口中启动
   - 修改代码后按 Ctrl+Shift+F5 重新启动调试会话

### 添加新功能

**示例：添加新命令**

在 `extension.ts` 中：
```typescript
context.subscriptions.push(
    vscode.commands.registerCommand('stm32-serial-monitor.newCommand', async () => {
        // 新功能实现
    })
);
```

在 `package.json` 中添加命令定义：
```json
{
    "command": "stm32-serial-monitor.newCommand",
    "title": "New Command",
    "category": "STM32"
}
```

## 构建和发布

### 打包VSIX文件

```bash
# 全局安装vsce工具
npm install -g @vscode/vsce

# 打包扩展
vsce package

# 输出：stm32-serial-monitor-1.0.0.vsix
```

### 发布到VS Code Marketplace

```bash
# 需要Microsoft账号和发布者账户
vsce publish
```

## 故障排查日志

启用调试日志：

```bash
# 开发模式运行
code --user-data-dir=/tmp/vscode-debug --log=debug

# 查看开发者工具
# 在扩展的调试窗口中：Ctrl+Shift+I
```

## 贡献指南

欢迎提交问题和改进建议！

## 许可证

MIT License

## 常见问题

### Q: 可以同时监控多个COM端口吗？

A: 当前版本支持单个COM端口。多端口支持在规划中。

### Q: 如何持久化配置？

A: 配置自动保存到VS Code的用户设置。使用"Select COM Port"命令修改。

### Q: 可以在远程连接中使用吗？

A: 支持VS Code远程SSH连接，但需要在远程主机安装serialport包。

### Q: 如何联系开发者？

A: 在项目仓库中提交Issue。

---

**祝调试愉快！🎯**
