<p align="center">
  <img src="assets/app-icon.png" width="128" height="128" alt="xBar Icon" />
</p>

<h1 align="center">xBar</h1>

<p align="center">
  <b>A lightweight, elegant, and modular menu bar manager for macOS.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-blue?style=flat-square" alt="Platform: macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=flat-square" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License: GPL-3.0" />
  <a href="https://github.com/XERA-2011/sponsor"><img src="https://img.shields.io/badge/Sponsor-❤️-ff69b4.svg?style=flat-square" alt="Sponsor" /></a>
</p>

---

## Overview

**xBar** keeps your macOS menu bar clean and organized. Hide inactive status items and expand them on demand through native in-bar expansion or a notch-friendly floating panel.

---

## ⚡ Operation Modes

xBar provides two distinct operation modes tailored to your workflow:

<p align="center">
  <img src="assets/operation-modes.png" alt="xBar Operation Modes" width="760" />
</p>

- **Native Bar**: Expands hidden icons directly inside the macOS menu bar. Clean single-layer experience with ultra-low power consumption and zero extra windows.
- **Floating Bar**: Displays hidden items in an interactive floating panel anchored directly below the menu bar item. Bypasses MacBook notch clipping and renders 1:1 live items.

---

## 🖥 System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or later.
- **Permissions**:
  - **Accessibility** *(Required)*: Enables menu bar item arrangement and click routing.
  - **Screen Recording** *(Optional)*: Required only for live icon capture in Floating Bar mode.

---

## 📦 Installation

Download the latest release package (`xBar.dmg`) from [GitHub Releases](https://github.com/XERA-2011/x-bar/releases). Open the DMG and drag **xBar** into your `Applications` folder.

---

## 🛠 Building from Source

```bash
# Clone the repository
git clone https://github.com/XERA-2011/x-bar.git
cd x-bar

# Build the release application bundle (outputs to dist/xBar.app)
./scripts/build-app.sh release

# Or package into DMG, ZIP and checksums (outputs to dist/)
./scripts/package.sh
```

The output bundle will be located at `dist/xBar.app` (or `dist/xBar.dmg`). Move it to `/Applications` to run.

---

## 🙏 Acknowledgements

xBar builds upon the ideas and pioneering work of the open-source community:

- **[jordanbaird/Ice](https://github.com/jordanbaird/Ice)** — The powerful menu bar manager for macOS.
- **[thaw-app/Thaw](https://github.com/thaw-app/Thaw)** — Modern macOS menu bar enhancement suite.

## ❤️ Support & Sponsor

If you find xBar helpful, consider [sponsoring the project](https://github.com/XERA-2011/sponsor). Your support helps keep the project maintained!

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
