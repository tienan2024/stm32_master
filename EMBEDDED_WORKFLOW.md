# Claude Code × STM32 嵌入式全流程开发指南

> 从 AI 生成代码 → Keil MDK/CMake 编译 → STM32CubeProgrammer 烧录 → ST-Link GDB 调试

---

## 目录

1. [工具链概览](#1-工具链概览)
2. [环境配置](#2-环境配置)
3. [项目结构](#3-项目结构)
4. [Skill 配置](#4-skill-配置)
5. [日常开发流程](#5-日常开发流程)
6. [常见问题](#6-常见问题)

---

## 1. 工具链概览

| 环节 | 工具 | 说明 |
|------|------|------|
| **AI 辅助编程** | Claude Code | 本会话，生成固件代码 |
| **代码编译** | Keil MDK 或 CMake/Ninja | 编译 STM32 固件 |
| **固件烧录** | STM32CubeProgrammer CLI | 通过 ST-Link 烧录到芯片 |
| **在线调试** | ST-Link GDB Server + arm-none-eabi-gdb | 单步调试固件 |
| **代码格式** | clang-format | 统一代码风格 |
| **静态检查** | cppcheck | AI 过滤嵌入式误报 |

### 工具路径自动检测

所有工具路径由脚本自动检测，无需硬编码：

```
STM32CubeProgrammer CLI : %LOCALAPPDATA%\stm32cube\bundles\programmer\*\bin\STM32_Programmer_CLI.exe
Keil UV4                : 注册表 / 标准安装路径 (可参数覆盖)
CMake                  : %LOCALAPPDATA%\stm32cube\bundles\cmake\*\bin\cmake.exe
GDB                    : %LOCALAPPDATA%\stm32cube\bundles\gnu-gdb-for-stm32\*\bin\arm-none-eabi-gdb.exe
ST-Link GDB Server     : %LOCALAPPDATA%\stm32cube\bundles\stlink-gdbserver\*\bin\ST-LINK_gdbserver.exe
```

---

## 2. 环境配置

### 2.1 代理配置（大陆网络必选）

如果访问 GitHub 需要代理：

```powershell
# 配置 Git 代理（端口换成你实际的代理端口）
git config --global http.proxy http://127.0.0.1:9985
git config --global https.proxy http://127.0.0.1:9985
```

### 2.2 Git 全局配置

```powershell
git config --global user.name "your_name"
git config --global user.email "your_email@example.com"
```

### 2.3 工具路径参数覆盖（可选）

当工具不在标准位置时，传入参数指定：

```powershell
# 编译 + 烧录（指定 Keil 路径）
.\build_flash.ps1 -ProjectDir "F:\my_stm32_project" -UV4Path "C:\Keil\UV4\UV4.exe"

# 调试（指定各工具路径）
.\start_debug.ps1 -ProjectDir "F:\my_stm32_project" `
  -UV4Path "C:\Keil\UV4\UV4.exe" `
  -GDBPath "C:\...\arm-none-eabi-gdb.exe" `
  -GDBServerPath "C:\...\ST-LINK_gdbserver.exe" `
  -ProgrammerPath "C:\...\STM32_Programmer_CLI.exe"
```

### 2.4 环境变量速查

| 变量 | 用途 |
|------|------|
| `%LOCALAPPDATA%\stm32cube\bundles\` | STM32 工具链bundle根目录 |
| `%ProgramFiles(x86)%\Keil\UV4\` | Keil MDK 安装目录 |

---

## 3. 项目结构

```
my_stm32_project/
├── Apps/                      # 应用层代码
│   ├── UI/                    # UI 框架
│   │   ├── ui.c / ui.h       # 核心 UI
│   │   ├── ui_anim.c/h      # 动画引擎
│   │   ├── ui_theme.c/h     # 主题系统
│   │   ├── ui_view.c/h      # 视图切换
│   │   ├── ui_widgets.c/h    # 手表风格组件
│   │   └── ui_demo.c/h      # 演示程序
│   └── ...
├── Core/                      # STM32CubeMX 生成代码
├── Drivers/                   # 硬件驱动（BSP）
│   └── BSP/LCD/lcd.c/h       # LCD 驱动
├── Middlewares/               # 中间件（FatFS、MALLOC 等）
├── Output/                    # 编译输出 (*.axf, *.hex, *.map)
├── Projects/MDK-ARM/         # Keil 工程文件
│   └── *.uvprojx
├── CMakeLists.txt            # CMake 项目（可选）
└── build/                    # CMake 构建目录（可选）
```

### 识别项目类型

```powershell
# Keil MDK 项目（*.uvprojx）
Test-Path "$ProjectDir\Projects\MDK-ARM\*.uvprojx"

# CMake/Ninja 项目
Test-Path "$ProjectDir\CMakeLists.txt"
```

---

## 4. Skill 配置

### 4.1 安装 Skill

Skill 仓库：`https://github.com/tienan2024/stm32_master`

```powershell
# Clone 到本地 skills 目录（路径必须是 Claude Code 加载 skill 的标准位置）
git clone https://github.com/tienan2024/stm32_master.git `
  "C:\Users\<your_user>\.claude\skills\stm32_master"
```

### 4.2 Skill 目录结构

```
C:\Users\<you>\.claude\skills\stm32_master\
├── build_flash.ps1      # 编译 + 烧录
├── start_debug.ps1       # GDB 调试 / RTT Viewer / 串口 Shell
├── SKILL.md            # Skill 元信息（Claude Code 识别）
├── README.md            # 使用文档
└── templates/           # 代码生成模板
    ├── fal_module.c/h.tmpl
    ├── device_uart.c.tmpl
    └── ...
```

### 4.3 在 Claude Code 中调用

Claude Code 会话中直接说：

```
# 编译 + 烧录
请用 stm32_master skill 编译并烧录 F:\my_stm32_project

# 单独烧录
使用 stm32_master skill 烧录（跳过编译）

# 启动调试
使用 stm32_master skill 启动 GDB 调试会话

# RTT Viewer
使用 stm32_master skill 打开 RTT Viewer
```

---

## 5. 日常开发流程

### 流程图

```
[AI 生成代码]
      ↓
[Claude Code 编辑器]
      ↓
[build_flash.ps1 编译]
      ↓ 成功？
  是 ↓
[烧录到 STM32 芯片]
      ↓
[start_debug.ps1 GDB 调试]
      ↓
[验证功能] ←──┐
      ↓       │
     否      │
      ↓      │
[回到 AI 修复问题] ┘
```

### 5.1 编译 + 烧录（一键）

```powershell
# 项目目录（可以是相对路径或绝对路径）
$project = "F:\my_stm32_project"

# 编译 + 烧录
.\build_flash.ps1 -ProjectDir $project

# 仅烧录（跳过编译，用于调试阶段）
.\build_flash.ps1 -ProjectDir $project -SkipBuild
```

**成功输出示例：**

```
========================================
  STM32 Universal Build & Flash
========================================
Project: F:\my_stm32_project

[1/5] Detecting project type...
  Project type: Keil MDK (UVPROJX)

[2/5] Finding tools...
  Programmer: C:\Users\<user>\AppData\Local\...\STM32_Programmer_CLI.exe
  UV4: C:\Keil\UV4\UV4.exe

[3/5] Building project...
  Project: F:\my_stm32_project\Projects\MDK-ARM\project.uvprojx
  Build complete (0 errors)

[4/5] Finding ELF file...
  Found: F:\my_stm32_project\Output\project.axf

[5/5] Flashing to device...
  Device Info: STM32F103 High-density, 512KB Flash
  ...
  SUCCESS: Flash completed!
  Firmware: 64.29 KB
========================================
```

### 5.2 单独编译

```powershell
# Keil MDK
& "C:\Keil\UV4\UV4.exe" -j0 -o "Output\build.log" -b "Projects\MDK-ARM\project.uvprojx"

# CMake/Ninja
cmake --build build --config Debug
```

### 5.3 GDB 在线调试

```powershell
# 启动 GDB Server 并打开交互式调试
.\start_debug.ps1 -ProjectDir $project -GDBClient

# 或启动 VSCode 调试视图（需要 launch.json 配置）
.\start_debug.ps1 -ProjectDir $project
```

**GDB 常用命令（交互模式）：**

```
target remote localhost:61234    # 连接 GDB Server
file project.axf                # 加载符号
load                           # 下载固件到芯片
break main                     # 在 main 断点
continue                       # 运行
next                           # 单步（跳过函数）
step                           # 单步（进入函数）
print variable_name           # 打印变量
info registers                # 查看寄存器
x/16x 0x08000000             # 查看内存
```

### 5.4 RTT Viewer（需要 J-Link）

```powershell
.\start_debug.ps1 -ProjectDir $project -RTT
```

### 5.5 串口 Shell

```powershell
# 自动检测可用串口
.\start_debug.ps1 -ProjectDir $project -Shell -BaudRate 115200
```

---

## 6. 常见问题

### Q: 提示 "No ST-Link found"

```powershell
# 检查 ST-Link 连接
STM32_Programmer_CLI.exe -c port=SWD

# 可能原因：
# 1. USB 连接触不良 → 换一个 USB 端口
# 2. ST-Link 驱动未安装 → 安装 ST-Link 驱动
# 3. 芯片被加密（读保护）→ 先解除读保护：STM32_Programmer_CLI.exe -c port=SWD -e full
```

### Q: 提示 "Keil UV4 not found"

```powershell
# 手动指定路径
.\build_flash.ps1 -ProjectDir $project -UV4Path "C:\你的路径\UV4.exe"
```

### Q: 编译成功但烧录失败

```powershell
# 检查 ELF 文件是否存在
Get-ChildItem "Output\*.axf"

# 检查芯片连接
STM32_Programmer_CLI.exe -c port=SWD

# 尝试擦除后重新烧录
STM32_Programmer_CLI.exe -c port=SWD -e full
```

### Q: GDB 连接失败 "Connection refused"

```powershell
# 确认 GDB Server 已启动
netstat -an | Select-String "61234.*LISTENING"

# 如果没有启动，手动启动
Start-Process "ST-LINK_gdbserver.exe" -ArgumentList "-d -p 61234"
```

### Q: GitHub 推送失败（网络问题）

```powershell
# 确认代理配置
git config --global --get http.proxy

# 如果没有，配置代理
git config --global http.proxy http://127.0.0.1:你的端口
git config --global https.proxy http://127.0.0.1:你的端口
```

### Q: 如何更新 Skill 到最新版本？

```powershell
cd "C:\Users\<you>\.claude\skills\stm32_master"
git pull origin main
```

---

## 附录：关键文件速查

| 文件 | 作用 |
|------|------|
| `Output\*.axf` | 编译产物（烧录用） |
| `Output\*.map` | 符号表（调试用） |
| `Output\build.log` | Keil 编译日志（查错用） |
| `Projects\MDK-ARM\*.uvprojx` | Keil 工程文件 |
| `Core/Src/main.c` | 入口函数（断点常放这里） |
| `Drivers/BSP/LCD/lcd.c` | LCD 驱动（显示调试） |

---

## 相关仓库

| 仓库 | 地址 |
|------|------|
| stm32_master Skill | https://github.com/tienan2024/stm32_master |
| 本项目固件 | https://github.com/tienan2024/STM32F103ZET6-worktree |
