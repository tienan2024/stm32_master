---
name: stm32-build-flash
description: Use when compiling any STM32 project via CMake/Ninja or Keil MDK, flashing firmware via STM32CubeProgrammer CLI, debugging via ST-Link GDB Server, or using RTT Viewer, serial shell, code formatting, and static lint for STM32 devices.
---

# STM32 Build, Flash & Debug (Extended)

## 功能概览

| 功能 | 说明 |
|------|------|
| **Build** | CMake/Ninja 或 Keil MDK 编译，显示固件大小 |
| **Flash** | STM32CubeProgrammer CLI 烧录 |
| **Debug** | GDB 调试、RTT Viewer、串口 Shell |
| **Format** | clang-format 代码格式化 |
| **Lint** | cppcheck 静态检查 + AI 误报过滤 |

## 编译+烧录（一键）

### 使用方式

```powershell
# 编译并烧录（自动检测项目类型：CMake 或 Keil MDK）
.\build_flash.ps1 -ProjectDir "F:\path\to\project"

# 仅烧录（跳过编译）
.\build_flash.ps1 -ProjectDir "F:\path\to\project" -SkipBuild
```

### 支持的项目类型

| 类型 | 检测方式 |
|------|---------|
| **Keil MDK** | `Projects/MDK-ARM/*.uvprojx` |
| **CMake/Ninja** | 根目录 `CMakeLists.txt` |

### 成功输出示例

```
========================================
  STM32 Universal Build & Flash
========================================

Project: F:\path\to\project

[1/5] Detecting project type...
  Project type: Keil MDK (UVPROJX)

[2/5] Finding tools...
  Programmer: C:\Users\ROG\AppData\Local\stm32cube\bundles\programmer\2.22.0+st.1\bin\STM32_Programmer_CLI.exe
  UV4: D:\keil5\UV4\UV4.exe

[3/5] Building project...
  Project: F:\path\to\project\Projects\MDK-ARM\atk_f103.uvprojx
  Build complete (0 errors)

[4/5] Finding ELF file...
  Found: F:\path\to\project\Output\atk_f103.axf

[5/5] Flashing to device...
  ...

========================================
  SUCCESS: Flash completed!
  Firmware: 55.52 KB
========================================
```

---

## build - 单独编译项目

### CMake/Ninja

```powershell
cmake --build <project>/build --config Debug
```

### Keil MDK

```powershell
& "D:\keil5\UV4\UV4.exe" -j0 -o "<log_path>" -b "<project>.uvprojx"
```

### 成功输出示例

```
✅ 编译成功

📊 固件大小：
   text    data     bss     dec     hex filename
  45678    1234    5678   52590    cd6e build/Debug/test2.elf

💾 Flash 占用: 46912 / 524288 bytes (8.9%)
📦 RAM 占用:   6912 / 131072 bytes (5.3%)
```

### 错误诊断

```
❌ 编译失败 (2 个错误)

📍 错误 1: Core/Src/main.c:45
   undefined reference to 'HAL_TIM_PWM_Start'

   💡 分析: CubeMX 中可能没有启用 TIM PWM 功能
   🔧 建议: 在 CubeMX 中启用对应的 TIM 外设

📍 错误 2: fal/motor.c:23
   undefined reference to 'vTaskDelay'

   💡 分析: FreeRTOS 头文件未包含或配置缺失
   🔧 建议: 添加 #include "FreeRTOS.h" 和 "task.h"
```

### 常见编译错误

| 错误类型 | 原因 | 修复方法 |
|---------|------|---------|
| `undefined reference to 'HAL_XXX'` | HAL 驱动未启用 | 在 CubeMX 中启用对应外设 |
| `undefined reference to 'vTaskDelay'` | FreeRTOS 未配置 | 添加 FreeRTOSConfig.h 和 include 路径 |
| `No such file or directory` (头文件) | include 路径缺失 | 检查 CMakeLists.txt 中的 C_INCLUDES |
| `implicit declaration` | 缺少 #include | 添加对应的头文件 |
| `multiple definition` | 头文件中定义了变量 | 使用 extern 声明 |
| `region 'FLASH' overflow` | Flash 空间不足 | 优化代码或检查链接脚本 |
| `undefined reference to 'main'` | 链接脚本或启动文件错误 | 检查 LDSCRIPT 和 STARTUP 配置 |

---

## flash - 烧录固件

### 功能说明

使用 STM32CubeProgrammer CLI 烧录固件到芯片。

### 使用方式

```powershell
# 烧录 ELF/AXF
& $programmer -c port=SWD --download "<elf_path>" -v
```

### 成功输出示例

```
✅ 烧录成功

📡 调试器: ST-Link (SWD)
📦 固件: test2.elf (3.73 KB)
📍 地址: 0x08000000
⏱️  耗时: 0.28 秒
🔍 验证: 通过
```

### 常用命令

| 任务 | 命令 |
|------|------|
| 烧录 ELF | `STM32_Programmer_CLI.exe -c port=SWD --download <elf> -v` |
| 烧录 HEX | `STM32_Programmer_CLI.exe -c port=SWD --download <hex>` |
| 查看设备 | `STM32_Programmer_CLI.exe -c port=SWD` |
| 擦除芯片 | `STM32_Programmer_CLI.exe -c port=SWD -e full` |
| 复位 | `STM32_Programmer_CLI.exe -c port=SWD -rst` |

---

## debug - 调试会话

### 功能说明

启动 GDB Server 进行调试，支持 RTT Viewer 和串口 Shell。

### 使用方式

```powershell
# GDB 调试（默认）
.\start_debug.ps1 -ProjectDir "<path>"

# GDB 交互模式
.\start_debug.ps1 -ProjectDir "<path>" -GDBClient

# RTT Viewer
.\start_debug.ps1 -ProjectDir "<path>" -RTT

# 串口 Shell
.\start_debug.ps1 -ProjectDir "<path>" -Shell
```

### GDB 调试模式

```
✅ GDB Server 已启动

📡 调试器: ST-Link (SWD)
🔌 GDB 端口: localhost:61234

连接方式：

方式 1 — 命令行 GDB:
   arm-none-eabi-gdb build/Debug/test2.elf
   (gdb) target remote localhost:61234
   (gdb) load
   (gdb) break main
   (gdb) continue

方式 2 — VS Code:
   按 F5 启动调试
```

### RTT Viewer 模式

```
✅ RTT Viewer 已启动

📡 RTT 通道 0 已连接
💡 提示: 确保固件中已初始化 SEGGER_RTT

前置条件:
   1. J-Link 调试器连接
   2. 固件调用 SEGGER_RTT_Init()
   3. RTT 输出通道已配置
```

### 串口 Shell 模式

```
✅ 串口终端信息

🔌 端口: 自动检测可用 COM 端口
📊 波特率: 115200

手动连接方式:
   1. PuTTY: Serial, COMx, 115200
   2. TeraTerm: 相同设置
   3. STM32CubeProgrammer: ST-LINK > Serial Port
```

### GDB 常用命令

| 命令 | 说明 | 状态 |
|------|------|------|
| `target remote localhost:61234` | 连接 GDB Server | ✅ |
| `file <elf>` | 加载符号文件 | ✅ |
| `break main` | 在 main 设置断点 | ✅ |
| `continue` | 运行到断点 | ✅ |
| `next` | 单步执行（跳过函数） | ✅ |
| `step` | 单步执行（进入函数） | ✅ |
| `print <var>` | 打印变量值 | ✅ |
| `info registers` | 显示寄存器 | ✅ |
| `info locals` | 显示局部变量 | ✅ |
| `x/16x <addr>` | 查看内存（Flash） | ✅ |
| `where` / `bt` | 堆栈回溯 | ✅ |
| `list` | 显示源码 | ✅ |
| `kill` | 停止调试会话 | ✅ |

---

## format - 代码格式化

### 功能说明

使用 clang-format 格式化业务层代码，统一代码风格。

### 使用方式

```powershell
# 安装 clang-format (如果未安装)
winget install LLVM.LLVM

# 格式化指定文件
clang-format -i Core/Src/main.c

# 格式化目录
clang-format -i fal/motor/

# 仅检查格式（CI 模式）
clang-format --dry-run --Werror Core/Src/main.c
```

### 格式化范围

| 层级 | 目录 | 默认格式化 |
|------|------|----------|
| 业务层 | fal/, pal/, common/, utilities/, drivers/ | ✅ 是 |
| 应用层 | Core/Src/, Core/Inc/ | ✅ 是 |
| HAL 层 | Drivers/STM32F1xx_HAL_Driver/ | ❌ 否 |
| CMSIS | Drivers/CMSIS/ | ❌ 否 |

### 输出示例

```
✅ 格式化完成

📊 统计:
   格式化文件: 12 个
   修改文件: 5 个
   跳过文件: 7 个（已符合规范）

💡 提示: 使用 git diff 查看修改内容
```

---

## lint - 静态检查

### 功能说明

使用 cppcheck 进行静态代码检查，AI 分析结果并过滤嵌入式误报。

### 使用方式

```powershell
# 安装 cppcheck (如果未安装)
winget install cppcheck.cppcheck

# 检查业务层代码
cppcheck --enable=warning,style,performance,portability `
    --suppress=missingIncludeSystem `
    fal/ common/ utilities/

# 检查指定文件（需要 include 路径）
cppcheck -I Core/Inc -I Drivers/CMSIS/Core/Include `
    fal/motor/motor.c
```

### AI 智能分析

**嵌入式常见误报（需过滤）**：

| 误报类型 | 说明 | 处理 |
|---------|------|------|
| `unreadVariable` | 写入硬件寄存器后不需要读取 | 忽略 |
| `variableScope` | ISR 共享的 volatile 变量 | 忽略 |
| `unusedFunction` | HAL 回调函数由框架调用 | 忽略 |
| `nullPointer` | 外设基地址宏（如 GPIOA） | 忽略 |
| 类型转换警告 | 寄存器地址 `(uint32_t *)0x40000000` | 忽略 |

### 输出示例

```
📊 静态检查报告

📍 发现 5 个问题 (1 个错误, 3 个警告, 1 个风格)

❌ 错误 (必须修复):
   1. fal/motor/motor.c:45
      [error] Array index out of bounds
      💡 数组 'buffer' 大小为 10，但访问了 index 12
      🔧 修改索引范围或增大数组大小

⚠️ 警告 (建议修复):
   2. common/utils.c:78
      [warning] Variable 'temp' is assigned but never used
      💡 变量已赋值但后续未使用
      🔧 移除未使用的变量

🔇 已过滤的误报: 3 个
   - 2 个寄存器写入模式
   - 1 个 HAL 回调函数模式
```

---

# 快速参考

## 工具路径（自动检测）

| 工具 | 检测位置 |
|------|---------|
| CMake | `%LOCALAPPDATA%\stm32cube\bundles\cmake\*\bin\cmake.exe` |
| STM32_Programmer_CLI | `%LOCALAPPDATA%\stm32cube\bundles\programmer\*\bin\STM32_Programmer_CLI.exe` |
| arm-none-eabi-gdb | `%LOCALAPPDATA%\stm32cube\bundles\gnu-gdb-for-stm32\*\bin\arm-none-eabi-gdb.exe` |
| ST-LINK_gdbserver | `%LOCALAPPDATA%\stm32cube\bundles\stlink-gdbserver\*\bin\ST-LINK_gdbserver.exe` |
| Keil UV4 | `D:\keil5\UV4\UV4.exe` 或 `${env:ProgramFiles(x86)}\Keil\UV4\UV4.exe` |

## 常用命令

| 任务 | 命令 |
|------|------|
| 编译+烧录 | `.\build_flash.ps1 -ProjectDir "<path>"` |
| 编译 (CMake) | `cmake --build <dir>/build --config Debug` |
| 编译 (Keil) | `& "D:\keil5\UV4\UV4.exe" -j0 -o "Output/build.log" -b "Projects/MDK-ARM/atk_f103.uvprojx"` |
| 烧录 | `STM32_Programmer_CLI.exe -c port=SWD --download <elf> -v` |
| 启动 GDB Server | `ST-LINK_gdbserver.exe -d -p 61234 -cp <programmer_bin>` |
| GDB 连接 | `arm-none-eabi-gdb.exe --batch -ex "target remote localhost:61234"` |
| 代码格式化 | `clang-format -i <file>` |
| 静态检查 | `cppcheck --enable=warning,style <path>` |

## 验证组件

| 组件 | 版本 | 路径 |
|------|------|------|
| CMake | 4.2.3+st.1 | `...\cmake\4.2.3+st.1\bin\cmake.exe` |
| STM32_Programmer_CLI | 2.22.0+st.1 | `...\programmer\2.22.0+st.1\bin\STM32_Programmer_CLI.exe` |
| arm-none-eabi-gdb | 14.3.1+st.2 | `...\gnu-gdb-for-stm32\14.3.1+st.2\bin\arm-none-eabi-gdb.exe` |
| ST-LINK_gdbserver | 7.13.0+st.3 | `...\stlink-gdbserver\7.13.0+st.3\bin\ST-LINK_gdbserver.exe` |
| Keil UV4 | 5.25.2+ | `D:\keil5\UV4\UV4.exe` |
| 芯片 | STM32F103 High-density | 0x414, Cortex-M3, 512KB |

---

# 常见问题

| 问题 | 解决方案 |
|------|---------|
| "No ST-Link found" | 检查 USB 连接，换一个 USB 端口 |
| "GDB Server 需要 STM32CubeProgrammer" | 使用 `-cp <programmer_bin>` 参数 |
| "ELF not found" | 先执行编译 |
| GDB 中路径有空格 | 使用短路径或复制到无空格目录 |
| RTT 无输出 | 确保固件中调用了 `SEGGER_RTT_Init()` |
| 串口端口被占用 | 关闭其他串口连接 |
| clang-format 未安装 | `winget install LLVM.LLVM` |
| cppcheck 未安装 | `winget install cppcheck.cppcheck` |
| Keil UV4 not found | 检查 `D:\keil5\UV4\UV4.exe` 是否存在 |

---

# Templates

模板文件位于 `templates/` 目录，用于代码生成。

## 模板列表

| 模板文件 | 用途 | 占位符 |
|----------|------|--------|
| `fal_module.h.tmpl` | FAL 模块头文件 | `{{MODULE_NAME}}`, `{{MODULE_NAME_UPPER}}`, `{{DATE}}` |
| `fal_module.c.tmpl` | FAL 模块实现 | 同上 |
| `device_uart.c.tmpl` | UART 驱动 | 同上 |
| `device_iic.c.tmpl` | I2C 驱动 | 同上 |
| `device_spi.c.tmpl` | SPI 驱动 | 同上 |
| `device_gpio.c.tmpl` | GPIO 驱动 | 同上 |
| `device_adc.c.tmpl` | ADC 驱动 | 同上 |
| `device_tim.c.tmpl` | 定时器/PWM 驱动 | 同上 |
| `device_can.c.tmpl` | CAN 驱动 | 同上 |
| `.clang-format.tmpl` | clang-format 配置 | 无 |
| `vscode_launch.json.tmpl` | VSCode 调试配置 | `{{TARGET}}`, `{{DEVICE}}`, `{{INTERFACE}}` |

## 使用方式

1. 复制模板到目标目录
2. 替换占位符为实际值
3. 根据项目需求修改代码
