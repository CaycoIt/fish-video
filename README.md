# MoYuPlayer 摸鱼播放器

macOS 原生视频播放器，专为摸鱼看网课设计。Swift + AppKit 开发，仅 2MB。

## 功能

- **文件夹播放列表** — `Cmd+O` 选择文件夹，自动加载所有视频，后台线程不卡UI
- **网络视频** — `Cmd+U` 输入URL播放（支持 MP4 / HLS m3u8 / MOV）
- **透明度控制** — `Cmd+]` 更透明 / `Cmd+[` 更不透明 / `Cmd+0` 重置
- **透明背景** — `Cmd+B` 切换，视频区域透明只显示画面，侧栏半透明
- **窗口置顶** — `Cmd+T` 或底部 📌 按钮，浮在最上层
- **快进/后退** — `→` / `←` 跳转10秒（底部有 ⏪10s / 10s⏩ 按钮）
- **倍速播放** — `[` / `]` 循环切换 0.5x ~ 3.0x
- **进度条** — 底部自定义进度条，拖拽跳转
- **自动连播** — 看完一集自动播下一集
- **时间显示** — 当前时间 / 总时长

## 快捷键

| 按键 | 功能 |
|------|------|
| `Cmd+O` | 打开文件夹 |
| `Cmd+U` | 打开URL |
| `Cmd+T` | 置顶切换 |
| `Cmd+B` | 透明背景切换 |
| `Cmd+]` | 更透明 |
| `Cmd+[` | 更不透明 |
| `Cmd+0` | 重置透明度 |
| `Space` | 播放/暂停 |
| `→` | 快进10秒 |
| `←` | 后退10秒 |
| `]` | 倍速+ |
| `[` | 倍速- |
| `Cmd+→` | 下一集 |
| `Cmd+←` | 上一集 |

## 编译

```bash
cd moyu-player && bash build.sh
```

产物在 `build/MoYuPlayer.app`，可直接 `open` 或拖入 `/Applications/`。

## 项目结构

```
moyu-player/
├── Sources/
│   ├── main.swift       # 入口 + AppDelegate + 菜单栏 + 窗口管理
│   └── Views.swift      # 播放列表 + 视频播放器 + 自定义Cell
├── Resources/
│   └── AppIcon.icns     # 应用图标
├── Info.plist           # App 配置
├── build.sh             # 编译打包脚本
└── .gitignore
```

## 技术栈

- Swift + AppKit + AVKit
- AVPlayer / AVPlayerView 视频播放
- NSWindow.alphaValue 透明度（公开API，macOS 26兼容）
- NSWindow.isOpaque + backgroundColor=.clear 透明背景
- NSWindow.level=.floating 置顶
- 后台线程文件枚举

## 摸鱼组合

```
Cmd+B 透明背景 + Cmd+T 置顶 = 视频浮在代码上，只有画面可见
```
