# Paste Formatter

Paste Formatter is a simple macOS menu bar app that pastes formatted content from your clipboard. The original issue it solves is copying rich text including links, while stripping unwanted fonts and colors before pasting into another app.

![Paste Formatter](Header.jpg)

## Features

- Paste formatted clipboard content in the active app from Paste Formatter's menu in the menu bar or using a global keyboard shortcut
- Choose whether to preserve fonts when pasting
- Choose whether to preserve colors when pasting
- Choose whether to preserve links when pasting
- Choose whether to preserve list markers and indentation in text-only fields
- Choose whether to preserve paragraph breaks in text-only fields
- Change the default keyboard shortcut
- Launch the app automatically at login

## Download

You can download releases via [Releases](https://github.com/nielsmouthaan/paste-formatter/releases).

[![Buy Me a Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=☕&slug=nielsmouthaan&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/nielsmouthaan)

Consider supporting this and other free/open source projects I maintain by [buying me a coffee](https://buymeacoffee.com/nielsmouthaan). Also, check out my other apps:

- [Daily](https://dailytimetracking.com/?utm_source=pasteformatter), a popular Mac time tracker that works without timers
- [Ejectify](https://ejectify.app/?utm_source=pasteformatter), safely eliminates “Disk Not Ejected Properly” notifications
- [Backup Status](https://backupstatus.app/?utm_source=pasteformatter), a Time Machine status widget for macOS

## Build

To build your own copy, check out this repository, ensure you have [Xcode](https://developer.apple.com/xcode/) and its [command-line tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/) installed, and run:

```bash
./scripts/build-app.sh --bundle-identifier <BUNDLE_IDENTIFIER>
```

This creates `dist/Paste Formatter.app`.

To sign the app bundle as well, pass the name of a code signing identity available in your local keychain:

```bash
./scripts/build-app.sh \
  --bundle-identifier <BUNDLE_IDENTIFIER> \
  --signing-identity "<SIGNING_IDENTITY>"
```

To create a zipped notarized release build, use:

```bash
./scripts/build-app.sh \
  --bundle-identifier <BUNDLE_IDENTIFIER> \
  --signing-identity "<SIGNING_IDENTITY>" \
  --notarize \
  --release-zip
```

To create a signed Mac App Store installer package, use:

```bash
./scripts/build-app.sh \
  --bundle-identifier <BUNDLE_IDENTIFIER> \
  --signing-identity "3rd Party Mac Developer Application: <NAME> (<TEAMID>)" \
  --installer-signing-identity "3rd Party Mac Developer Installer: <NAME> (<TEAMID>)" \
  --provisioning-profile "<PROFILE.provisionprofile>" \
  --app-store-package
```

## Contribute

Contributions are welcome. Feel free to open an issue for bugs or feature requests, or open a pull request directly.

## Frequently asked questions

### How does this app work?

Paste Formatter reads the current clipboard contents, creates a cleaned version based on your selected options, temporarily puts that cleaned version on the clipboard, and then simulates `Command-V` in the active app.

### Why do I need this app?

It is useful when you want to paste rich text content without carrying over unwanted styling from the source, while still keeping the formatting you do want, such as links.

### Why not use “Paste and Match Style”?

“Paste and Match Style” often removes more than just unwanted styling. It can also remove elements you may want to keep, such as links.

### Why does the app need Accessibility permissions in System Settings?

The app uses Accessibility permissions to simulate `Command-V` after preparing the cleaned clipboard content. Without that permission, it can still clean the clipboard, but you will need to paste manually.

### What's the minimum macOS version?

macOS 13 or later.

### What does “Preserve Paragraph Breaks in Plain Text” do?

Some apps paste only plain text and ignore rich-text paragraph spacing. When this option is enabled, Paste Formatter tries to preserve paragraph breaks more clearly for those text-only targets.

### What does “Preserve Lists in Plain Text” do?

Some rich-text lists store their bullets, numbering, and nesting as list metadata instead of plain characters. When this option is enabled, Paste Formatter adds visible list markers and simple indentation to the plain-text version used by text-only fields.

### Will this work together with my clipboard manager?

Paste Formatter temporarily places formatted content on your clipboard before pasting it, so your clipboard manager may capture an extra copy. If that happens, configure your clipboard manager to ignore Paste Formatter.

### Can I hide the menu bar icon?

You can control whether Paste Formatter appears in the menu bar via System Settings. See [this article](https://support.apple.com/guide/mac-help/MCHLAD96D366) for instructions.

## License

See [LICENSE](LICENSE).
