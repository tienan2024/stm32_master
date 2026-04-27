# STM32 Build, Flash & Debug Skill

嵌入式 STM32 开发工作流，支持编译、烧录、调试、代码格式化和静态检查。

## 快速开始

### 编译 + 烧录
```powershell
.\build_flash.ps1 -ProjectDir "F:\path\to\project"
```

### 调试
```powershell
.\start_debug.ps1 -ProjectDir "F:\path\to"           # VSCode 调试
.\start_debug.ps1 -ProjectDir "F:\path\to" -GDBClient  # GDB 终端调试
.\start_debug.ps1 -ProjectDir "F:\path\to" -RTT      # RTT Viewer
.\start_debug.ps1 -ProjectDir "F:\path\to" -Shell     # 串口 Shell
```

## 工具链路径

所有工具自动检测来自 STM32Cube bundles：

| 工具 | 路径模式 |
|------|---------|
| CMake | `%LOCALAPPDATA%\stm32cube\bundles\cmake\*\bin\cmake.exe` |
| STM32_Programmer_CLI | `%LOCALAPPDATA%\stm32cube\bundles\programmer\*\bin\STM32_Programmer_CLI.exe` |
| arm-none-eabi-gdb | `%LOCALAPPDATA%\stm32cube\bundles\gnu-gdb-for-stm32\*\bin\arm-none-eabi-gdb.exe` |
| ST-LINK_gdbserver | `%LOCALAPPDATA%\stm32cube\bundles\stlink-gdbserver\*\bin\ST-LINK_gdbserver.exe` |

## GDB 调试命令

```bash
target remote localhost:61234    # 连接
file build/Debug/test2.elf      # 加载符号
break main                       # 断点
continue                         # 运行
next                            # 单步
print <var>                     # 打印变量
info registers                   # 寄存器
```

## 模板文件

`templates/` 目录下包含代码生成模板：

| 模板 | 用途 |
|------|------|
| `fal_module.h/.c` | FAL 业务模块框架 |
| `device_uart.c` | UART 设备驱动 |
| `device_iic.c` | I2C 设备驱动 |
| `device_spi.c` | SPI 设备驱动 |
| `device_gpio.c` | GPIO 设备驱动 |
| `device_adc.c` | ADC 设备驱动 |
| `device_tim.c` | 定时器/PWM 驱动 |
| `device_can.c` | CAN 设备驱动 |
| `.clang-format.tmpl` | 代码格式化配置 |
| `vscode_launch.json.tmpl` | VSCode 调试配置 |

## 占位符

模板中使用以下占位符：

| 占位符 | 说明 |
|--------|------|
| `{{MODULE_NAME}}` | 模块名（小写） |
| `{{MODULE_NAME_UPPER}}` | 模块名（大写） |
| `{{DATE}}` | 当前日期 |
| `{{DEVICE}}` | 芯片型号 |
| `{{TARGET}}` | 项目名称 |
| `{{INTERFACE}}` | 调试接口（SWD/JTAG） |

## 格式化

```bash
# 安装 clang-format
winget install LLVM.LLVM

# 格式化代码
clang-format -i Core/Src/main.c
```

## 静态检查

```bash
# 安装 cppcheck
winget install cppcheck.cppcheck

# 检查代码
cppcheck --enable=warning,style fal/ common/
```

## 验证的组件

| 组件 | 版本 |
|------|------|
| CMake | 4.2.3+st.1 |
| STM32_Programmer_CLI | 2.22.0+st.1 |
| arm-none-eabi-gdb | 14.3.1+st.2 |
| ST-LINK_gdbserver | 7.13.0+st.3 |
| 芯片 | STM32F103 High-density |
