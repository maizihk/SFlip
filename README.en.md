# SFlip

[简体中文](README.md) | [English](README.en.md)

[![macOS CI](https://github.com/maizihk/SFlip/actions/workflows/macos.yml/badge.svg)](https://github.com/maizihk/SFlip/actions/workflows/macos.yml)
[![Windows CI](https://github.com/maizihk/SFlip/actions/workflows/windows.yml/badge.svg)](https://github.com/maizihk/SFlip/actions/workflows/windows.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

SFlip is a macOS menu bar and Windows system tray app for computers that share external monitors. It controls monitor brightness, contrast and volume, and works with a USB switch to change monitor inputs. Switching a keyboard and mouse requires a USB switch or KVM.

## Features

- **Monitor controls**: Adjust each monitor separately or link them to adjust all monitors together.
- **Automatic USB switching**: Change monitor inputs when a selected USB device disconnects, and wake local displays when it reconnects.
- **Computer collaboration**: Choose a target computer from the menu to wake its displays and switch monitor inputs.
- **Media keys**: Use keyboard brightness, volume and mute keys to control external monitors.

## Download and install

Current releases: Windows **v2.4.1**, macOS **v2.4.1**. See the [release notes](https://github.com/maizihk/SFlip/releases) for changes in each version.

| Platform | Requirements | Download |
| --- | --- | --- |
| macOS | Apple Silicon, macOS 12 or later | [DMG](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SFlip-v2.4.1-macOS-arm64.dmg) · [ZIP](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SFlip-v2.4.1-macOS-arm64.zip) |
| Windows | x64, Windows 10 1809 or later | [Installer](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SFlip-v2.4.1-Windows-x64-Setup.exe) · [Portable ZIP](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SFlip-v2.4.1-Windows-x64-portable.zip) |

- **macOS**: Open the DMG, drag `SFlip.app` into `Applications`, then launch it from Applications. For the ZIP, extract it and move the app to Applications. If the first launch is blocked, follow the [Mac installation guide](macOS/INSTALL.md#installing-sflip-on-macos) to approve it in System Settings.
- **Windows installer**: Run the installer and follow the setup wizard. If a required runtime is missing, install it and retry.
- **Windows portable version**: Install [Windows App Runtime 2.4 x64](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/downloads), extract the entire ZIP and run `SFlip.exe`. Keep the adjacent `runtime` folder.

Quit the previous version before upgrading. Checksums: [Windows](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SHA256SUMS.txt) · [macOS](https://github.com/maizihk/SFlip/releases/download/v2.4.1/SHA256SUMS.txt).

## Basic usage


### Interface language

In Settings → General → Language, choose System, 简体中文 or English. The default is System: Chinese system languages use Simplified Chinese; other system languages use English.

### Monitor controls

1. Open Settings and click Detect Displays on the Displays page.
2. Enable the brightness, contrast or volume controls you need, then click Read DDC Parameters to confirm the readings.
3. Adjust the sliders. Enable the corresponding tray options to access controls from the menu bar or system tray.

Enable media keys in General. On macOS, this requires Input Monitoring permission; optional HDMI/DP volume handling also requires Accessibility permission.

### Automatic USB switching

1. On the USB Switching page, select or learn a device that disconnects when you switch the USB switch.
2. Enter the target input source number for each participating monitor. Leave it blank for monitors that should not switch.
3. Enable automatic USB switching. When the device disconnects, SFlip switches monitor inputs; when it reconnects, SFlip wakes local displays.

See the [input source guide](docs/INPUT_SOURCES.md) for finding input source numbers. Before the first test, confirm that you can return to the original input using the monitor's physical buttons.

### Computer collaboration

1. Run SFlip on both computers and connect them to the same trusted local network.
2. On each computer's Collaboration page, enter a profile name, the other computer's address, the same port and the same pairing code. The default port is `49731`; an 8–128 character code using letters or numbers is recommended.
3. Enter input source numbers for participating monitors, then enable the profile. A complete profile can be enabled and saved even while the other computer is offline.
4. Click Detect Connection to view the result. Once connected, choose the target profile from the menu bar or system tray to switch to that computer.

Automatic USB switching can work independently. To also wake the other computer, enable collaboration linking on the USB page and select a collaboration profile.

## Compatibility and support

Your monitor must support DDC/CI and have it enabled. Cables, adapters, docks and KVMs must also pass these commands through. Some monitors support only a subset of controls, such as brightness; HDMI/DP volume control also depends on the monitor's capabilities.

macOS currently supports Apple Silicon. Windows requires Windows App Runtime 2.4 x64. See [hardware compatibility](COMPATIBILITY.md) for more device information.

For problems, start with the [support guide](SUPPORT.md), then submit a compatibility report or an [issue](https://github.com/maizihk/SFlip/issues). For security concerns, contact the maintainer as described in the [security policy](SECURITY.md). Some linked guides are currently in Chinese.

## Build from source

From the repository root:

- **macOS**: Requires full Xcode 27 and Python 3. Run `./macOS/scripts/build-app.sh`.
- **Windows**: Requires Visual Studio 2026 with the C++ desktop development and Windows App SDK components. Run `.\Windows\build-windows.ps1`.

See the [Windows README](Windows/README.md) for installer builds and detailed dependencies, and the [contributing guide](CONTRIBUTING.md) for development guidelines.

## License

SFlip is licensed under the [MIT License](LICENSE). The macOS DDC backend is based on [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC). See [third-party notices](THIRD_PARTY_NOTICES.md).
