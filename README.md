# MouseKu

A small menu bar utility that makes a regular USB or Bluetooth mouse nicer to use on macOS.

## Features

- Remap the middle button and buttons 4 to 7: click, double click, hold, click and drag, click and scroll
- Actions such as Back, Forward, Mission Control, App Exposé, Show Desktop, Spaces and custom shortcuts
- Smooth scrolling with momentum, adjustable speed and smoothness
- Mouse scroll direction is reversed by default, so the trackpad can stay on natural scrolling
- Optional trackpad simulation (bounce at page edges); one tick the other way catches a coasting page
- Modifier + scroll: Shift (horizontal), Command (zoom), Option (precise), Control (fast)
- Launch at login

## Download and install

Requires macOS 14 or later (Apple Silicon or Intel).

1. Open the [latest release](https://github.com/saddadnabbil/MouseKu/releases/latest) and download `MouseKu-<version>.zip`.
2. Unzip it and drag **MouseKu.app** into your **Applications** folder.
3. Open MouseKu. The app is not notarized by Apple, so macOS blocks it the first time.
   Click **Done**, open **System Settings > Privacy & Security**, scroll down, click **Open Anyway**, and confirm.

   If you prefer the terminal, this removes the download quarantine flag instead:

   ```sh
   xattr -dr com.apple.quarantine /Applications/MouseKu.app
   ```

Only do step 3 if you downloaded the file from this repository.

## Accessibility permission

MouseKu cannot read or change mouse input without it.

1. In MouseKu, on the **General** tab, turn on **Enable MouseKu**.
2. Click **Open Accessibility Settings**, or go to **System Settings > Privacy & Security > Accessibility**.
3. Turn on **MouseKu**. If it is not listed, click **+** and choose `/Applications/MouseKu.app`.
4. The orange warning in MouseKu disappears within a second or two.

Optionally turn on **Launch at login** on the General tab.

### The warning stays although MouseKu is switched on

This happens after updating: the app is ad-hoc signed, so macOS does not match the old permission to the new build.
Select MouseKu in the Accessibility list, remove it with **-**, then add it again with **+**. Or run:

```sh
tccutil reset Accessibility local.mouseku
```

## Uninstall

Turn off **Launch at login**, quit MouseKu from the menu bar, delete it from Applications,
and remove it from the Accessibility list.

## Build from source

Requires the Xcode Command Line Tools.

```sh
./test.sh    # logic tests
./build.sh   # creates build/MouseKu.app (universal)
```

## Privacy and security

- No network access, analytics or logging.
- The event tap only receives middle/extra button, drag and scroll wheel events, not typing.
- Built with the hardened runtime. The app is not sandboxed, because it must post input events.
- Settings live in user defaults. Any process running as your user can edit them, including custom shortcuts.
- Uses a private Apple API for Mission Control, Exposé and Show Desktop,
  so a macOS update can break those features.

## Limitations

- If natural scrolling is off in System Settings, turn off **Reverse scroll direction**.
- Switching Spaces needs the Control + arrow shortcuts to be enabled in System Settings.
- Zoom is sent as Command + / Command -, not as a pinch gesture.
