# xBar

<p align="center">
  <b>轻量、纯粹、优雅的 macOS 菜单栏管理工具</b><br />
  A lightweight, elegant, and single-process menu bar manager for macOS.
</p>

---

## ✨ 核心特性

- **菜单栏图标收纳**：支持“隐藏”与“始终隐藏”多层分区，快速隐藏不常用的图标，保持菜单栏干净清爽。
- **多维度展开交互**：支持点击主控图标、鼠标悬停、菜单栏滚轮滑动或全局自定义快捷键随心展开。
- **悬浮拓展栏 (IceBar)**：完美适配 MacBook 刘海屏，将隐藏图标呈现于独立悬浮栏中，点击直接唤出应用菜单，彻底告别刘海遮挡困扰。
- **个性化外观美化**：支持实色与渐变着色、自适应壁纸色彩采样、阴影、边框轮廓以及圆角/分段菜单栏形态。
- **极简单进程架构**：去除了冗余的后台守护服务与重度依赖，整体体积仅约 14MB，低能耗、极低内存占用。
- **隐私至上**：零统计、零遥测埋点、无需网络账户，完全本地运行。

---

## 🖥 系统要求

- **操作系统**：macOS 14.0 或更高版本 (macOS Sonoma / Sequoia 及最新系统)
- **系统权限**：首次运行需授予 **辅助功能 (Accessibility)** 权限以实现图标位置调度与交互点击（“屏幕录制”权限为可选，仅用于捕获动态图标渲染与壁纸取色）。

---

## 🛠 本地构建

```bash
# 克隆仓库
git clone https://github.com/XERA-2011/x-bar.git
cd x-bar

# 编译并打包 Release 版本
./scripts/build-app.sh release
```

构建完成后，打包出的独立应用位于 `dist/xBar.app`，直接拖入 `/Applications` 即可使用。

---

## 🙏 参考与致谢

xBar 的开发汲取了开源社区的智慧与灵感，特别感谢以下优秀项目：

- **[jordanbaird/Ice](https://github.com/jordanbaird/Ice)** — 强大的 macOS 菜单栏隐藏与外观定制先驱项目。
- **[thaw-app/Thaw](https://github.com/thaw-app/Thaw)** — 现代化的开源菜单栏增强套件与设计实践。

---

## 📄 开源许可

本项目遵循 [GPL-3.0 许可证](LICENSE) 开源。
