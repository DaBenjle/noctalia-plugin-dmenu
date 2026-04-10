# noctalia-dmenu

A [rofi -dmenu](https://github.com/davatorium/rofi) replacement plugin for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell). Present arbitrary choices through Noctalia's launcher UI and get the selection back in your scripts.

## Features

- **Drop-in dmenu replacement** — pipe items in, get the selection out
- **Full Noctalia integration** — uses the native launcher with all its animations, theming, and search
- **Session-based state machine** — rock-solid chaining with no race conditions
- **Flexible input** — stdin pipes, files, or structured JSON via IPC
- **Flexible output** — result files, callbacks, or direct command execution
- **Custom input** — optionally allow users to type values not in the list
- **Configurable** — settings UI in Noctalia, plus per-invocation overrides
- **Extensible** — JSON item format supports icons, descriptions, and metadata

## Installation

### Manual

```bash
cd ~/.config/noctalia/plugins/
git clone https://github.com/DaBenjle/noctalia-plugin-dmenu dmenu
```

Add to `~/.config/noctalia/plugins.json` under `"states"`:

```json
{
  "states": {
    "dmenu": {
      "enabled": true
    }
  }
}
```

Restart Noctalia, then enable the plugin in Settings → Plugins.

Optionally, put the helper script on your PATH for pipe-style usage:

```bash
ln -s ~/.config/noctalia/plugins/dmenu/noctalia-dmenu ~/.local/bin/noctalia-dmenu
```

## Quick start

### Pipe style (like `rofi -dmenu`)

Requires the `noctalia-dmenu` helper script on your PATH.

```bash
echo -e "Firefox\nChromium\nZen Browser" | noctalia-dmenu -p "Browser:"

# Capture the result
BROWSER=$(echo -e "Firefox\nChromium\nZen" | noctalia-dmenu -p "Browser:")
echo "You chose: $BROWSER"
```

### Direct IPC

```bash
# Simple items (no JSON needed)
noctalia-shell ipc call plugin:dmenu showSimple "Firefox|Chromium|Zen" "|" "Browser:" ""

# Structured items with descriptions and icons
noctalia-shell ipc call plugin:dmenu showJson '{
    "items": [
        {"name": "Firefox", "value": "firefox", "description": "Web browser", "icon": "browser"},
        {"name": "Zen", "value": "zen", "description": "Privacy focused", "icon": "shield"}
    ],
    "prompt": "Launch:"
}' x
```

> **Note:** `showJson` takes a dummy second argument (`x`) due to a quirk in Quickshell's CLI argument parser that rejects single-argument IPC calls. `showSimple` (4 args) works without the workaround.

### With callbacks (fire-and-forget)

```bash
noctalia-shell ipc call plugin:dmenu showSimple \
    "Firefox|Chromium|Zen" "|" "Open:" "gtk-launch {}"
```

## IPC reference

All commands: `noctalia-shell ipc call plugin:dmenu <command> [args...]`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `showJson` | `configJson` `unused` | Show items from a JSON config (see below) |
| `showSimple` | `items` `separator` `prompt` `callbackCmd` | Show a flat list of items |
| `showFromFile` | `filePath` `separator` `prompt` `callbackCmd` | Read items from a file |
| `toggle` | *(none)* | Toggle launcher with `>dmenu` prefix |
| `close` | *(none)* | Cancel current session and close launcher |
| `clear` | *(none)* | Reset state without closing launcher |

### JSON config format

```json
{
    "items": [
        {
            "name": "Display text",
            "value": "return value",
            "description": "Optional subtitle",
            "icon": "tabler-icon-name"
        }
    ],
    "prompt": "Choose:",
    "callbackCmd": "handler.sh {}",
    "resultFile": "/tmp/noctalia-dmenu-result",
    "resultFormat": "plain",
    "allowCustomInput": false,
    "closeOnSelect": true,
    "maxResults": 200
}
```

Items can be strings (`["a","b","c"]`) or objects with `name`, `value`, `description`, and `icon` fields. The `{}` placeholder in `callbackCmd` is replaced with the selected value. Additional placeholders: `{value}`, `{index}`, `{name}`.

## Helper script reference

```
noctalia-dmenu [OPTIONS]

Input (one of):
  stdin                      Pipe items, one per line
  -f, --file PATH            Read items from a file
  -j, --json CONFIG          Pass full JSON config directly

Options:
  -p,  --prompt TEXT         Prompt/header text
  -cb, --callback CMD        Run CMD on selection ({} = result)
  -c,  --custom              Allow custom text input
  -s,  --separator SEP       Item separator (default: newline)
  -t,  --timeout SECS        Wait timeout (default: 30, 0 = infinite)
  -r,  --result-file PATH    Override result file path
  -F,  --format FMT          Result format: plain, json, index
  -no-close                  Keep launcher open after selection
  -h,  --help                Show help

Exit codes:
  0    Selection made
  1    Timeout or cancelled
  2    Error
```

## Chaining (multi-step menus)

The session-based architecture guarantees clean sequencing:

1. Script calls `showJson` → launcher opens with items
2. User selects an item
3. Plugin writes result file (atomic tmp+mv)
4. Plugin closes launcher
5. Plugin ends session (state is clean)
6. Plugin fires callback (which may call `showJson` again)

Steps 3–5 are synchronous. Step 6 runs asynchronously, so a chained `showJson` always starts with a clean slate.

```bash
#!/usr/bin/env bash
# power-menu.sh — called by a keybind
CATEGORY=$(echo -e "Power\nDisplay\nNetwork" | noctalia-dmenu -p "System:")
case "$CATEGORY" in
    "Power")
        ACTION=$(echo -e "Shutdown\nReboot\nSuspend" | noctalia-dmenu -p "Power:")
        case "$ACTION" in
            "Shutdown") systemctl poweroff ;;
            "Reboot")   systemctl reboot ;;
            "Suspend")  systemctl suspend ;;
        esac ;;
esac
```

## Settings

Configure defaults in Settings → Plugins → Dmenu Provider → Configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Result file path | `/tmp/noctalia-dmenu-result` | Where selections are written |
| Result format | `plain` | `plain`, `json`, or `index` |
| Allow custom input | `false` | Let users type non-listed values |
| Custom input prefix | *(empty)* | Prefix added to custom input values |
| Close on select | `true` | Auto-close after selection |
| Show toast | `false` | Toast notification on selection |
| Default separator | `\n` | For `showSimple` mode |
| Max results | `200` | Cap on displayed items |

All settings can be overridden per-invocation via IPC args.

## Testing

Run the interactive test suite:

```bash
./test-dmenu.sh      # all tests
./test-dmenu.sh 3    # run just test 3
```

## File structure

```
dmenu/
├── manifest.json          # Plugin metadata
├── Main.qml               # IPC handlers and session state machine
├── LauncherProvider.qml   # Feeds items into Noctalia's launcher
├── Settings.qml           # Settings UI
├── noctalia-dmenu         # Helper script (symlink to ~/.local/bin/)
├── test-dmenu.sh          # Interactive test suite
├── i18n/
│   └── en.json            # English translations
├── settings.json          # User settings (auto-generated, gitignored)
└── README.md
```

## License

MIT
