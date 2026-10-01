# ROG P711 patchB

为 ASUS ROG Gladius III Wireless AimPoint（P711）固件 `V03.00.10` 提供一个可复现的二进制补丁，用于绕开会持续误报“按下”的顶部 DPI 键输入。

> [!IMPORTANT]
> patchB 是故障隔离方案，不是 DPI 键修复方案。刷入后左/右/中键、侧键、滚轮、移动、灯效及连接功能可恢复正常，但顶部 DPI 键会失效。

本仓库不重复分发华硕固件、刷写程序或 DLL。双击脚本会直接从 ASUS 官方服务器下载指定版本，校验官方 SHA-256 后再调用其中的刷写程序。

## 适用症状

已验证设备出现以下组合症状：

- DPI 档位或灯效自行切换；
- 普通点击和滚轮被抑制，但光标仍能移动；
- 重启或重刷官方固件后故障仍然存在；
- 将按键引擎槽 5 与 P1.11 隔离后，其余功能恢复正常。

如果你的故障现象不同，请不要使用此补丁。

## 根因

固件按键引擎的槽 5 读取 GPIO `P1.11`，对应顶部 DPI 键。故障设备上的该输入持续为低电平，因此固件将其视为一直按住。

按住 DPI 键约 3 秒会进入 DPI On-The-Scroll 模式，滚轮随后用于调整 DPI，而不再滚动页面。patchB 将槽 5 的读取位由 P1.11 改到 P1.12，从而绕开异常线路。

这属于软件规避：如果 P1.11 存在硬件短路、微动损坏或线路故障，固件无法从一个始终不变化的低电平判断真实按键动作。

更完整的逆向说明见 [docs/technical-notes.md](docs/technical-notes.md)。

## 严格兼容范围

仅支持：

- 设备：ASUS ROG Gladius III Wireless AimPoint（P711）
- 固件：`P711_MOUSE_V03_00_10.bin`
- 文件大小：`1,044,480` 字节
- 原版 SHA-256：`051FD11B4383B59FA10C273A692912FA750F3157068DD45CE38EAB7135C1FD12`

脚本会验证完整 SHA-256、文件大小、原始补丁字节和固件内部校验。任一项目不匹配都会停止，不会尝试兼容其他版本。

## 一键安装

1. 下载本仓库并解压；
2. 双击 `run-patchB.cmd`；
3. 脚本从 ASUS 官方服务器下载并校验更新包；
4. 将鼠标切换到有线模式并插入 USB 线；
5. 按提示输入 `PATCHB` 后开始刷写。

自动下载的官方包为：

```text
P711_FirmwareAutoUpdate_1.0.0.20.zip
SHA-256: 88B2F60DBD56553B5407AA65176669A09DBCCE5A1C8D4CBB7C5E72BCFDCD962C
```

下载来源是 [ASUS 官方支持服务器](https://dlcdnets.asus.com/pub/ASUS/Accessory/Keyboard_Mouse/ROG_GLADIUS_III_WIRELESS_AIMPOINT/P711_FirmwareAutoUpdate_1.0.0.20.zip?model=ROG%20GLADIUS%20III%20WIRELESS%20AIMPOINT)。缓存位于仓库下的 `.vendor` 文件夹，可随时删除。

刷写时必须：

1. 将鼠标切换到有线模式；
2. 使用 USB 线直接连接电脑；
3. 保持供电，刷写完成前不要拔线；
4. 关闭可能占用鼠标的 Armoury Crate 页面。

## 离线或手动使用

如果已经从 [ASUS 官方支持页面](https://rog.asus.com/mice-mouse-pads/mice/wireless/rog-gladius-iii-wireless-aimpoint-model/helpdesk_download/) 下载并解压更新包，可以把包含下列文件的 `Firmware` 文件夹拖到 `run-patchB.cmd` 上：

```text
P711_MOUSE_V03_00_10.bin
peripheral_fwu_pro.exe
相关 DLL
```

也可以运行 PowerShell：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-patchB.ps1 `
  -FirmwareDirectory "C:\path\to\Firmware" -Install
```

只生成补丁而不刷写：

```powershell
.\install-patchB.ps1 -FirmwareDirectory "C:\path\to\Firmware"
```

输出文件：

```text
P711_MOUSE_V03_00_10_patchB.bin
```

预期 patchB SHA-256：

```text
8BB73F1132A149F5EC6B0FA34E6CC71D4A22BC36AFCE64CF00D8222A6ABE8DB0
```

## 预期结果

- 鼠标移动、左右键、中键、侧键和页面滚动正常；
- LED 灯效恢复正常；
- 顶部 DPI 键不可用，这是 patchB 的设计结果；
- DPI 仍可通过 Armoury Crate 配置。

## 恢复官方固件

如果刷写失败并停留在 Bootloader，请保持鼠标连接，不要断电，使用官方更新工具重新刷入未经修改的 `P711_MOUSE_V03_00_10.bin`。

官方刷写命令格式为：

```text
peripheral_fwu_pro.exe m 1A70 1A71 112 200 FF01 FF01 4 P711_MOUSE_V03_00_10.bin CVER:n
```

## 风险提示

- 这是未经 ASUS 官方认可的社区补丁，使用风险由用户自行承担。
- 固件刷写存在设备暂时进入 Bootloader 或刷写失败的风险。
- 不要将本补丁用于其他型号或固件版本。
- 脚本不会修改原始 `.bin`，只会创建新的 patchB 文件。

## License

补丁脚本和文档采用 [MIT License](LICENSE)。ASUS、ROG 及相关产品名称属于其各自权利人；本项目与 ASUS 无隶属或认可关系。
