# 🔌 STM32 Serial Monitor VS Code 扩展安装指南

## 快速安装（推荐）

### Windows 用户

1. **打开命令行或PowerShell**
   ```powershell
   # 导航到扩展目录
   cd c:\Users\ROG\.claude\skills\stm32_master\vscode-extension
   ```

2. **运行安装脚本**
   ```batch
   setup.bat
   ```
   
   脚本会自动：
   - ✅ 安装Node.js依赖
   - ✅ 编译TypeScript
   - ✅ 构建VSIX包
   - ✅ 安装到VS Code

3. **重启VS Code**
   - 关闭并重新打开VS Code
   - 扩展应该已启用

### Mac/Linux 用户

```bash
cd vscode-extension

# 安装依赖
npm install

# 编译
npm run compile

# 打包（需要安装vsce）
npm install -g @vscode/vsce
vsce package

# 安装到VS Code
code --install-extension stm32-serial-monitor-*.vsix
```

---

## 手动安装

如果自动脚本失败，按以下步骤手动安装：

### 第1步：安装Node.js

从 https://nodejs.org/ 下载并安装LTS版本

验证安装：
```bash
node --version  # 应该显示 v14.0.0 或更高
npm --version
```

### 第2步：安装依赖

```bash
cd vscode-extension
npm install
```

### 第3步：编译

```bash
npm run compile
```

会生成 `out/` 文件夹

### 第4步：安装vsce

```bash
npm install -g @vscode/vsce
```

### 第5步：构建VSIX

```bash
vsce package
```

生成文件：`stm32-serial-monitor-1.0.0.vsix`

### 第6步：安装扩展

**方式A：命令行**
```bash
code --install-extension stm32-serial-monitor-1.0.0.vsix
```

**方式B：VS Code UI**
1. 打开VS Code
2. 按 `Ctrl+Shift+X` 打开扩展面板
3. 点击右上角 `⋯` 菜单
4. 选择 "从VSIX安装..."
5. 选择 `stm32-serial-monitor-1.0.0.vsix` 文件

### 第7步：重启VS Code

关闭并重新打开VS Code，扩展应该被激活。

---

## 验证安装

### 检查扩展是否已安装

1. 按 `Ctrl+Shift+X` 打开扩展面板
2. 搜索 "STM32 Serial Monitor"
3. 应该显示已安装

### 查看扩展活动栏

1. 左侧活动栏应该出现新的图标
2. 点击它打开"Serial Monitor"视图
3. 如果看到"Serial Monitor"面板，说明安装成功

---

## 使用指南

### 第一次使用

1. **打开Serial Monitor视图**
   - 点击左侧活动栏的串口图标
   - 或按 `Ctrl+Shift+P` 输入 "Open Serial Monitor"

2. **选择COM端口**
   - 点击"Select"按钮
   - 从列表中选择STM32连接的COM端口
   - （如果列表为空，检查USB连接）

3. **启动监控**
   - 点击"Start"按钮
   - 应该看到实时串口数据流入

4. **使用过滤**
   - 在搜索框输入关键词（支持正则表达式）
   - 点击"Filter"只显示匹配的行

### 常用操作

| 按钮 | 功能 |
|------|------|
| Start | 开始监控 |
| Stop | 停止监控 |
| Clear | 清空显示 |
| Export | 下载日志 |
| Select | 选择COM端口 |

### 快捷命令

按 `Ctrl+Shift+P` 打开命令面板：

```
STM32: Start Monitoring     # 启动
STM32: Stop Monitoring      # 停止
STM32: Clear Output         # 清空
STM32: Download Log         # 下载
STM32: Select COM Port      # 选择端口
```

---

## 配置选项

打开VS Code设置 (`Ctrl+,`)，搜索 "stm32"：

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `stm32.serialMonitor.port` | 空 | COM端口（COM1-COM9） |
| `stm32.serialMonitor.baudRate` | 115200 | 波特率 |
| `stm32.serialMonitor.dataBits` | 8 | 数据位数 |
| `stm32.serialMonitor.stopBits` | 1 | 停止位 |
| `stm32.serialMonitor.parity` | none | 奇偶校验 |
| `stm32.serialMonitor.autoScroll` | true | 自动滚动 |
| `stm32.serialMonitor.maxLines` | 5000 | 最大缓冲行数 |

**在settings.json中配置：**

```json
{
    "stm32.serialMonitor.port": "COM3",
    "stm32.serialMonitor.baudRate": 115200,
    "stm32.serialMonitor.autoScroll": true
}
```

---

## 故障排查

### 问题：扩展未出现在活动栏

**解决方案：**
```bash
# 检查扩展是否真的安装了
code --list-extensions | findstr stm32

# 如果未出现，重新安装
vsce package
code --install-extension stm32-serial-monitor-*.vsix --force
```

### 问题：无法找到COM端口

**检查清单：**
1. ✅ USB线连接正常
2. ✅ 在设备管理器中查看 (Windows: `devmgmt.msc`)
3. ✅ 驱动程序已安装
4. ✅ COM端口未被其他程序占用

```powershell
# Windows: 列出所有COM端口
[System.IO.Ports.SerialPort]::GetPortNames()

# Linux/Mac: 列出所有串口
ls /dev/tty* | grep -E "USB|serial"
```

### 问题：收不到数据

**检查：**
1. ✅ 点击了"Start"按钮
2. ✅ 波特率与STM32固件设置相同
3. ✅ STM32固件初始化了UART
4. ✅ 数据线连接正常

**STM32代码示例：**
```c
// 初始化UART1 @ 115200
HAL_UART_Init(&huart1);

// 发送数据
HAL_UART_Transmit(&huart1, (uint8_t*)"Hello\r\n", 7, 100);

// 或使用printf（需要重定向）
printf("Temperature: 25.5°C\r\n");
```

### 问题：串口乱码

**解决：**
- 确认波特率正确：`8N1` (8数据位，无奇偶校验，1停止位)
- 查看设置中的 `dataBits`, `stopBits`, `parity`

### 问题：过滤不工作

**检查正则表达式：**
- ✅ `ERROR` - 匹配包含ERROR的行
- ✅ `ERROR|WARN` - 匹配ERROR或WARN
- ✅ `^\[.*\]` - 匹配以[开头的行
- ❌ `[` - 无效的正则表达式

### 问题：扩展崩溃

**获取日志：**
```bash
# 打开开发者工具
# 在VS Code中按 Ctrl+Shift+I

# 或查看扩展宿主日志
code --log=/tmp/vscode-log
```

---

## 开发者模式

### 编辑和测试

1. **打开工作区**
   ```bash
   code vscode-extension
   ```

2. **启动调试**
   - 按 `F5`
   - VS Code会打开一个新窗口，加载此扩展
   - 修改代码后按 `Ctrl+R` 重新加载

3. **查看日志**
   - 在调试窗口中按 `Ctrl+Shift+I` 打开开发者工具
   - 查看console标签页的日志

### 编译和打包

```bash
# 监听文件变化自动编译
npm run watch

# 打包为VSIX
vsce package

# 验证编译结果
ls -la out/
```

---

## 常见问题（FAQ）

### Q: 可以监控多个COM端口吗？

A: 当前版本只支持单个COM端口。如果需要多端口监控，请在问题跟踪器中提出。

### Q: 为什么不显示某些数据？

A: 
- 检查是否启用了过滤器（过滤器可能隐藏了数据）
- 增加 `maxLines` 设置值
- 检查波特率是否正确

### Q: 如何在远程VS Code中使用？

A: 支持VS Code SSH远程。在远程主机上安装Node.js和依赖后，扩展应该正常工作。

### Q: 可以自定义颜色主题吗？

A: 当前使用VS Code的默认主题颜色。主题自定义将在未来版本中添加。

### Q: 扩展占用多少资源？

A: 内存占用约 50-100MB（取决于缓冲行数），CPU占用 < 2%（平均）。

---

## 获取帮助

### 常见命令

```bash
# 查看VS Code版本
code --version

# 列出已安装的扩展
code --list-extensions

# 查看扩展日志
code --log=verbose

# 重装扩展（强制）
code --install-extension stm32-serial-monitor-*.vsix --force

# 卸载扩展
code --uninstall-extension stm32.stm32-serial-monitor
```

### 获取支持

如果遇到问题：
1. 检查上方的故障排查章节
2. 查看VS Code的开发者工具日志
3. 在项目仓库中提交Issue（需要说明：OS、VS Code版本、错误信息）

---

## 下一步

✅ 安装完成后：
1. 选择COM端口
2. 启动监控
3. 开始实时查看STM32数据
4. 使用过滤查找关键信息
5. 导出日志进行分析

**祝使用愉快！🎯**

---

**需要帮助？** 按 `Ctrl+Shift+P` 并搜索 "STM32" 查看所有可用命令。
