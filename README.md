# MouseKu

A small menu bar utility that makes a regular USB or Bluetooth mouse nicer to use on macOS.

## Features

- Remap the middle button and buttons 4 to 7: click, double click, hold, click and drag, click and scroll
- Actions such as Back, Forward, Mission Control, App Exposé, Show Desktop, Spaces and custom shortcuts
- Smooth scrolling with adjustable speed and smoothness, optional reverse direction
- Modifier + scroll: Shift (horizontal), Command (zoom), Option (precise), Control (fast)
- Turns natural scrolling off while an external mouse is connected, and restores it afterwards
- Launch at login

## Build

Requires macOS 14 or later and the Xcode Command Line Tools.

```sh
./test.sh    # logic tests
./build.sh   # creates build/MouseKu.app
```

Move `MouseKu.app` to `/Applications`, open it, turn on **Enable MouseKu**, and grant Accessibility permission.

The app is ad-hoc signed. After rebuilding it, macOS no longer matches the old permission. Reset it and grant it again:

```sh
tccutil reset Accessibility local.mouseku
```

## Privacy and security

- No network access, analytics or logging.
- The event tap only receives middle/extra button, drag and scroll wheel events, not typing.
- Built with the hardened runtime. The app is not sandboxed, because it must post input events.
- Settings live in user defaults. Any process running as your user can edit them, including custom shortcuts.
- Uses private Apple APIs for Mission Control, Exposé, Show Desktop and the natural scrolling switch,
  so a macOS update can break those features.

## Limitations

- Natural scrolling is one macOS setting shared by mouse and trackpad.
- Switching Spaces needs the Control + arrow shortcuts to be enabled in System Settings.
- Zoom is sent as Command + / Command -, not as a pinch gesture.
