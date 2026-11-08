# Flotsam UI Scale 150%

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: Windows](https://img.shields.io/badge/platform-Windows-lightgrey)
![Game: Flotsam](https://img.shields.io/badge/game-Flotsam-1f6feb)

把 **《Flotsam》（漂流品）** 游戏内的 **UI 缩放上限从 125% 提高到 150%**，
（可选自定义 100%–200%），专治 4K / 高分屏下界面太小的问题。

- 只改 **4 个字节**（2 个场景文件 × 2 个滑块，每个滑块 1 字节），不改变游戏结构
- 自动识别游戏目录、自动做 **SHA-256 版本校验**，版本不对直接拒绝，不会改坏文件
- 自动备份，一条命令即可还原
- 游戏更新后重新运行一次即可

---

## 目录

- [这是什么](#这是什么)
- [适用游戏与版本](#适用游戏与版本)
- [效果](#效果)
- [为什么官方只到 125%](#为什么官方只到-125)
- [工作原理](#工作原理)
- [安装](#安装)
- [自定义缩放比例](#自定义缩放比例)
- [还原](#还原)
- [安全性说明](#安全性说明)
- [常见问题](#常见问题)
- [发布到 GitHub](#发布到-github)
- [文件结构](#文件结构)
- [移植到新版本](#移植到新版本)
- [免责声明](#免责声明)
- [License](#license)

---

## 这是什么

Flotsam 的画面设置里，「UI 缩放」滑块最高只能拉到 **125%**。
在 4K 显示器上，这个比例往往还是偏小。

本工具通过修改游戏场景文件中滑块组件的 `m_MaxValue`，
把上限提升到 **150%**（或你指定的任意比例），
让游戏内滑块可以正常拉到 150% 并保存，而不是改一次就被打回 125%。

适合人群：

- 4K / 2K 高分屏，觉得 125% 仍然太小
- 小尺寸高分辨率笔记本
- 不想（或不能）改 Windows 全局缩放，只想让这一个游戏大一点

## 适用游戏与版本

| 项目 | 内容 |
| --- | --- |
| 游戏 | **Flotsam**（中文常译「漂流品」「浮岛」） |
| 开发商 | Pajama Llama Games |
| 平台 | Steam（AppID `821250`）/ Epic Games Store / GOG |
| 类型 | 单机模拟经营 / 生存 |
| 已验证版本 | **1.1.0f5**（Unity `6000.3.26f1`，Windows x64，Epic 版） |
| 系统 | Windows 10 / 11 |

> Steam / GOG 版若与本仓库记录的 SHA-256 不一致，安装脚本会**拒绝执行并提示**，
> 不会误改。遇到这种情况请提交 Issue 并附上提示里的两个哈希值。

## 效果

| | 原版 | 打补丁后 |
| --- | --- | --- |
| 设置 → 画面 → UI 缩放 | 50% – **125%** | 50% – **150%**（默认） |
| 保存与重进游戏 | 正常 | 正常 |
| 游戏逻辑 / 存档 | — | 不受影响 |

## 为什么官方只到 125%

Flotsam 是 Unity 游戏，UI 缩放值保存在：

```
%USERPROFILE%\AppData\LocalLow\Pajama Llama Games\Flotsam\PlayerSettings.json
    → GraphicsPlayerData.UIScale
```

运行时由 `CanvasScaleSetter` 直接把 `UIScale` 赋给 `Canvas.scaleFactor`，
**代码里没有任何上限判断**。真正限制 125% 的，是场景文件里
`UIScaleSlider` 这个 Unity Slider 组件的 `m_MaxValue = 1.25`。
所以只要把这个值改成 1.5，游戏内滑块自然就能拉到 150%。

## 工作原理

1. 读取 `Flotsam_Data\level1`（主菜单场景）和 `level2`（游戏内场景）。
2. 两个文件里各有 2 个 `UIScaleSlider` 的 Slider 组件；
   其 `m_MaxValue` 位于对象起始偏移 `+0x154`。
3. 把该浮点数由 `1.25` 写成 `1.5`：每个滑块 4 字节里只有 1 个字节变化
   （`0xA0` → `0xC0`），两个场景共 4 处。
4. 同时把 `PlayerSettings.json` 的 `UIScale` 写成目标值，进游戏即生效。
5. 安装前会用 SHA-256 校验「把 1.25 写回后」的文件是否与已知原版完全一致，
   确认是受支持的版本才继续。

本仓库**不包含任何游戏原始文件**，补丁在你自己的电脑上现场生成。

## 安装

**前置条件：完全退出游戏**（包括 Epic / Steam 客户端里的 Flotsam 进程）。

### 方式一：双击安装（推荐）

1. 下载本仓库（`Code` → `Download ZIP`，或 `git clone`）并解压到任意目录。
2. 双击 **`install.bat`**。
3. Windows 弹出 UAC 时点「**是**」（补丁在 `Program Files` 下，需要管理员权限）。
4. 看到「完成！」后关闭窗口。
5. 启动游戏 → **设置 → 画面 → UI 缩放**，此时可以拉到 **150%**。

### 方式二：PowerShell 命令行

以**管理员身份**打开 PowerShell，进入本仓库目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

安装到非默认路径的游戏：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -GameDir "D:\Epic Games\Flotsam"
```

只想看看会发生什么、不修改任何文件（不需要管理员）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -WhatIf
```

## 自定义缩放比例

`-Scale` 参数范围 `1.0` – `2.0`，默认 `1.5`：

```powershell
:: 直接传参给 bat
install.bat -Scale 1.75

:: 或者用 PowerShell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Scale 1.6
```

> 建议不要超过 1.75：部分固定尺寸面板在更高比例下可能出现重叠。
> 随时可以重新运行安装脚本改成别的数值。

## 还原

双击 **`uninstall.bat`**（同样需要 UAC），或：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

会把两个场景文件恢复成原版，并把 `UIScale` 改回 `1.25`。

## 安全性说明

- **只改 4 个字节**：`level1` / `level2` 各 2 个字节（`0xA0` → `0xC0`），
  不新增、不删除任何数据，不改变文件结构。
- **版本校验**：安装前计算 SHA-256，只有已知的 1.1.0f5 原版才会被修改；
  其它版本、已被其它 MOD 改过的文件都会被拒绝。
- **自动备份**：原始文件会备份到
  `%LOCALAPPDATA%\FlotsamUIScale\backup\`，即使校验逻辑失效也能手动恢复。
- **可验证**：`install.ps1 -WhatIf` 只读不写。
- **游戏更新**会覆盖补丁，重新运行一次即可；不会残留损坏。
- 本工具只适用于**单机**游戏，不涉及联机、不绕过任何反作弊。

## 常见问题

**Q：安装完进游戏，UI 还是原来大小？**
先确认「设置 → 画面 → UI 缩放」滑块能不能超过 125%。如果滑块上限还是 125%，
说明补丁没有写入成功（多半是没退出游戏，或者 UAC 被拒绝）。

**Q：打开画面设置后，缩放又变回 125% 了？**
说明当前运行的不是打过补丁的 `level1/level2`（例如游戏刚更新过）。
重新运行 `install.bat` 即可。

**Q：提示「无法识别的游戏版本」？**
你的游戏版本（可能是 Steam 版或更新后的版本）与本仓库记录的不一致。
请在 Issues 里附上提示中显示的两个 SHA-256，以及游戏版本号。

**Q：界面元素重叠 / 超出屏幕？**
150% 对绝大多数界面没问题，但个别固定尺寸面板可能偏挤。
用 `install.bat -Scale 1.4` 调小一点，或运行 `uninstall.bat` 还原。

**Q：找不到游戏目录？**
用 `-GameDir` 指定，例如 `install.bat -GameDir "D:\Games\Flotsam"`。

## 发布到 GitHub

本仓库自带一个发布脚本，**不需要安装 GitHub CLI**，双击即可：

1. 双击 **`publish-to-github.bat`**。
2. 输入你的 GitHub 用户名，仓库名直接回车用默认的 `flotsam-ui-scale`。
3. 浏览器会自动打开 GitHub 的「新建仓库」页面：
   保持仓库名不变，**不要**勾选 *Add a README / .gitignore / license*，
   点绿色按钮 **Create repository**。
4. 回到命令行窗口按回车，脚本会自动 `git push`；
   第一次会弹出 GitHub 登录窗口，登录完成后自动推送。
5. 推送成功后自动打开仓库页面。

也可以带参数直接运行：

```bat
publish-to-github.bat -UserName octocat -RepoName my-flotsam-mod
```

只看计划、不真正推送：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-to-github.ps1 -UserName octocat -WhatIf
```

## 文件结构

```
flotsam-ui-scale/
├─ install.bat                  安装入口（自动请求管理员权限）
├─ uninstall.bat                还原入口（自动请求管理员权限）
├─ publish-to-github.bat        一键发布到 GitHub（可选）
├─ scripts/
│  ├─ install.ps1               安装逻辑：校验、备份、打补丁、写配置
│  ├─ uninstall.ps1             还原逻辑
│  ├─ run-elevated.ps1          提权启动器（处理含空格的路径与额外参数）
│  └─ publish-to-github.ps1     发布逻辑
├─ tools/
│  └─ find_ui_scale_slider.py   维护者工具：定位新版本的滑块偏移
├─ README.en.md                 English README
├─ LICENSE
└─ README.md
```

## 移植到新版本

游戏更新后偏移量可能变化。用仓库里的 Python 工具重新定位：

```bash
pip install UnityPy
python tools/find_ui_scale_slider.py "C:\Program Files\Epic Games\Flotsam\Flotsam_Data"
```

输出示例：

```
level1   object=0xa5dc0  min=0.5  max=1.25  whole=0  value=1
         sha256=A15A40BD...C61E13
```

把新的 `object` 偏移和 SHA-256 填进 `scripts/install.ps1`
顶部的 `$Offsets` / `$KnownHashes` 即可。

## 免责声明

- 本项目与 Pajama Llama Games 无关，非官方工具。
- 修改游戏文件存在一定风险，请自行评估；建议先备份存档。
- 请支持正版游戏。

## License

[MIT](LICENSE) —— 仅适用于本仓库的脚本与文档，不包含任何游戏资源。
