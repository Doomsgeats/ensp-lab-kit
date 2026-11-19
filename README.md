# ensp-lab-kit

在 Windows 上用脚本搭华为 **eNSP** 实验的几个小工具：生成 `.topo`、通过 console 批量下发配置、截图留证。

写它是因为 eNSP 这软件自己不会说话：拓扑是闭源 XML，控制台是带 telnet 协商的本地端口，GUI 点击还会跟 DPI 缩放打架。把这些都脚本化之后，一个实验从"手点四十分钟"变成"改一个 JSON、跑一条命令"。

## 里面有什么

| 文件 | 作用 |
| --- | --- |
| `ensp_topo.py` | 把 JSON 拓扑描述生成 eNSP 能直接打开的 `.topo`（S5700 / PC 混合，端口数任意） |
| `demo/ring4.json` | 四交换机环状 + 四台 PC 的示例拓扑 |
| `tools/vrp_console.py` | 直连 `127.0.0.1:<com_port>` 的 VRP 控制台客户端，处理 IAC 协商、`[Y/N]` 提示、`save` 交互 |
| `tools/ui.ps1` | DPI 感知的窗口工具：截图 / 点击 / 双击 / 右键 / 发送按键 |
| `tools/q.ps1` | 在指定标题的控制台窗口里打命令并截图（`CLS` 后逐条执行） |
| `tools/wshot.ps1` | 按窗口标题截取窗口区域（PrintWindow 之外用屏幕裁剪，颜色不失真） |

## 快速开始

```powershell
# 1) 生成拓扑
python ensp_topo.py demo/ring4.json demo/ring4.topo
#    console S5700 SD (127.0.0.1:2001) ...

# 2) 用 eNSP 打开它，然后启动设备（菜单 → 工具 → 启动设备，或 Ctrl+Alt+A）

# 3) 下发配置
python -c "from tools.vrp_console import VrpConsole; c=VrpConsole(2001); c.login(); \
print(c.run(['system-view','sysname SD','quit','save'], answers=['y',''])); c.close()"

# 4) 截图
powershell -File tools/q.ps1 -Title SD -Out shot.png -Cmds "display interface brief"
```

## 踩过的坑（按损失的时间排序）

**1. `com_port` 不等于设备顺序。** 每一台设备在 `.topo` 里都写死了自己的 `com_port`，打开后 eNSP 就按这个号监听。如果你按"第一台是 2001"想当然，会把四台交换机的配置**整体错位打进去**——现象是 OSPF 邻居半通不通、日志里冒 `Bad net segment`。永远先 `display version` 或读提示符确认是谁。

**2. 环形拓扑会被 STP 掐断。** 四台交换机连成环时 MSTP 会把某一个端口置成 `ALTE / DISCARDING`，于是某条链路看起来"物理通、ping 不通"，而且是单向的（对方计数在涨，本端收不到）。`display stp brief` 一看就知道，实验环境直接 `stp disable`。

**3. eNSP 的虚拟 PC 不会自己发 IGMP 报告。** 组播实验里把 PC 的"组播"页设好、点应用、重启设备，`display igmp group` 依然是空的；交换机侧 `Input: Multicast 0 packets` 就是证据。要演示 (S,G) 表项，用 `igmp static-group <group> source <src>` 在 Vlanif 上代打，并在报告里写明这是模拟器的限制。

**4. 控制台窗口最多同时开 3 个。** 第 4 个不会出现，也不会报错——你会以为设备没起来。

**5. VirtualBox 在新版 Win11 上起不来。** 报 `RTLdrOpenWithReader failed: Unknown Status -626 (0xfffffd8e)`，eNSP 里表现为"启动设备失败，错误代码 45"。**S5700 交换机用的是 eNSP 自己的模拟器，不需要 VBox**，只跑交换机的实验不受影响；路由器/AP 才需要。

**6. 配置不会随拓扑保存。** 每次关掉 eNSP 再打开，设备都回到出厂 `<Huawei>`，得重新下发。所以配置一定要落成脚本，而不是手敲。

**7. 抓窗口要处理 DPI。** 150% 缩放下逻辑坐标和物理坐标差 1.5 倍，未声明 DPI 感知的进程调用 `SetCursorPos` 会被夹到逻辑边界。`tools/ui.ps1` 开头调了 `SetProcessDPIAware()`，所以传的是物理坐标。

## 不包含什么

不含任何具体课程的实验答案（配置命令、题目、拓扑参数）。`demo/` 里是一份中性的四交换机环状拓扑，用来验证工具能跑。

## 许可证

MIT。