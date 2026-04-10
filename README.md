# noctalia-dmenu

A dmenu/rofi replacement for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell). Present choices through a Noctalia panel and get the selection back in your scripts.

## Install

```bash
cd ~/.config/noctalia/plugins/
git clone https://github.com/DaBenjle/noctalia-plugin-dmenu dmenu
```

Add to `~/.config/noctalia/plugins.json`:

```json
{ "states": { "dmenu": { "enabled": true } } }
```

Restart Noctalia, enable in Settings → Plugins.

For pipe-style usage, put the helper on your PATH:

```bash
ln -s ~/.config/noctalia/plugins/dmenu/noctalia-dmenu ~/.local/bin/noctalia-dmenu
```

## API

Two IPC methods. Both take an items argument and an options argument.

### `showItems` — plain text items

```
noctalia-shell ipc call plugin:dmenu showItems <items> <options>
```

`items` is a string of delimiter-separated values. `options` is a JSON string (or `""` for defaults).

```bash
# Pipe-delimited
noctalia-shell ipc call plugin:dmenu showItems "a|b|c" '{"separator":"|","prompt":"Pick:"}'

# Newline-delimited (default separator)
noctalia-shell ipc call plugin:dmenu showItems "one
two
three" '{"prompt":"Choose:"}'

# Minimal — no options needed
noctalia-shell ipc call plugin:dmenu showItems "yes|no" '{"separator":"|"}'
```

### `showJson` — structured items

```
noctalia-shell ipc call plugin:dmenu showJson <itemsArray> <options>
```

`itemsArray` is a JSON array. Items can be strings, objects, or a mix.

```bash
# Simple strings
noctalia-shell ipc call plugin:dmenu showJson '["Firefox","Chromium","Zen"]' '{"prompt":"Browser:"}'

# Objects with metadata
noctalia-shell ipc call plugin:dmenu showJson '[
  {"name":"Firefox","value":"firefox","description":"Web browser","icon":"browser"},
  {"name":"Zen","value":"zen","description":"Privacy focused","icon":"shield"}
]' '{"prompt":"Launch:","callbackCmd":"gtk-launch {}"}'

# Mixed
noctalia-shell ipc call plugin:dmenu showJson '["plain",{"name":"Rich","value":"rich","icon":"star"}]' ''

# With images
noctalia-shell ipc call plugin:dmenu showJson '[
  {"name":"Photo 1","value":"photo1","image":"/home/user/photos/1.jpg"},
  {"name":"Photo 2","value":"photo2","image":"/home/user/photos/2.jpg"}
]' ''
```

### Item object fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display text (required for objects) |
| `value` | string | Return value (defaults to `name`) |
| `description` | string | Subtitle text |
| `icon` | string | Tabler icon name (e.g. `"browser"`, `"star"`) |
| `image` | string | Absolute path to an image file (overrides `icon`) |

### Options

Passed as JSON string to both `showItems` and `showJson`. All fields are optional.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `separator` | string | `"\n"` | Delimiter for `showItems` (ignored by `showJson`) |
| `prompt` | string | `""` | Placeholder text in the search bar |
| `callbackCmd` | string | `""` | Command to run on selection. `{}` is replaced with the value. Also supports `{value}`, `{index}`, `{name}`. |
| `resultFile` | string | `/tmp/noctalia-dmenu-result` | Where to write the selection |
| `resultFormat` | string | `"plain"` | `"plain"` (raw value), `"json"` (structured), or `"index"` (item number) |
| `allowCustomInput` | bool | `false` | Allow typing values not in the list |
| `closeOnSelect` | bool | `true` | Close the panel after selection |
| `maxResults` | int | `200` | Maximum items to display |

### Other IPC commands

| Command | Args | Description |
|---------|------|-------------|
| `showFromFile` | `filePath` `options` | Read items from a file. Options JSON supports `separator`. |
| `toggle` | — | Toggle the panel open/closed |
| `close` | — | Cancel and close |
| `clear` | — | Reset state without closing |

## Helper script

The `noctalia-dmenu` script provides a pipe-friendly interface, similar to `rofi -dmenu`.

```bash
# Basic
echo -e "Power Off\nReboot\nSuspend" | noctalia-dmenu -p "Power:"

# Capture result
CHOICE=$(echo -e "yes\nno" | noctalia-dmenu -p "Continue?")

# Custom separator
echo "one::two::three" | noctalia-dmenu -s "::"

# From file
noctalia-dmenu -f /tmp/items.txt -p "Select:"

# With callback
echo -e "Firefox\nChromium" | noctalia-dmenu -p "Open:" -cb "gtk-launch {}"
```

### Options

```
-p,  --prompt TEXT        Placeholder text in search bar
-cb, --callback CMD       Run CMD on selection ({} = result)
-c,  --custom             Allow custom text input
-s,  --separator SEP      Item separator (default: newline)
-t,  --timeout SECS       Wait timeout (default: 30, 0 = infinite)
-r,  --result-file PATH   Override result file path
-f,  --file PATH          Read items from file instead of stdin
-F,  --format FMT         Result format: plain, json, index
-no-close                 Keep panel open after selection
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Selection made |
| 1 | Timeout or cancelled |
| 2 | Error |

## Chaining

Menus can be chained — each selection triggers the next.

```bash
#!/usr/bin/env bash
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

Or with callbacks (non-blocking):

```bash
noctalia-shell ipc call plugin:dmenu showJson \
    '["Power","Display","Network"]' \
    '{"prompt":"System:","callbackCmd":"~/.config/scripts/submenu.sh {}"}'
```

## Settings

Configure in Settings → Plugins → Dmenu Provider → Configure.

| Setting | Default | Description |
|---------|---------|-------------|
| Panel position | `follow_launcher` | Where the panel appears. `follow_launcher` uses launcher settings. Override with: `center`, `top_center`, `bottom_center`, `top_left`, `top_right`, `bottom_left`, `bottom_right`, `center_left`, `center_right` |
| Show match count | `true` | Show filtered/total count in footer |
| Show footer | `true` | Show the result count footer |
| Allow custom input | `false` | Default for allowing typed values not in the list |
| Custom input prefix | — | Prefix prepended to custom input values |
| Close on select | `true` | Auto-close panel after selection |
| Show toast | `false` | Toast notification on selection |
| Result file path | `/tmp/noctalia-dmenu-result` | Where selections are written |
| Default separator | `\n` | Default for `showItems` mode |
| Max results | `200` | Cap on displayed items |

All behavior settings can be overridden per-invocation via IPC options.

## Testing

```bash
./test-dmenu.sh       # all 18 tests
./test-dmenu.sh 11    # just the chaining test
```

## File structure

```
dmenu/
├── manifest.json       # Plugin metadata
├── Main.qml            # IPC handlers, session state machine
├── Panel.qml           # Search + list UI
├── Settings.qml        # Settings UI
├── noctalia-dmenu      # Helper script (link to ~/.local/bin/)
├── test-dmenu.sh       # Test suite
├── i18n/en.json        # Translations
├── settings.json       # User settings (gitignored)
└── README.md
```

## License

MIT
