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

### `showItems` — plain text items

For simple lists. Two arguments: items string and options JSON.

```bash
# Basic
noctalia-shell ipc call plugin:dmenu showItems "a|b|c" '{"separator":"|"}'

# With prompt
noctalia-shell ipc call plugin:dmenu showItems "yes|no" '{"separator":"|","prompt":"Continue?"}'

# With callback
noctalia-shell ipc call plugin:dmenu showItems "Firefox|Chromium" '{"separator":"|","callbackCmd":"gtk-launch {}"}'

# Default newline separator
noctalia-shell ipc call plugin:dmenu showItems "one
two
three" '{"prompt":"Pick:"}'
```

### `showJson` — structured items

For items with descriptions, icons, or images. Single argument: a JSON object with `items` array and options.

```bash
# Simple strings
noctalia-shell ipc call plugin:dmenu showJson '{"items":["alpha","beta","gamma"],"prompt":"Greek:"}'

# Objects with descriptions and icons
noctalia-shell ipc call plugin:dmenu showJson '{"items":[{"name":"Firefox","value":"firefox","description":"Web browser","icon":"browser"},{"name":"Zen","value":"zen","description":"Privacy focused","icon":"shield"}],"prompt":"Launch:"}'

# Mixed strings and objects
noctalia-shell ipc call plugin:dmenu showJson '{"items":["plain",{"name":"Rich","value":"rich","icon":"star","description":"Has metadata"}]}'

# With images
noctalia-shell ipc call plugin:dmenu showJson '{"items":[{"name":"Photo","value":"photo1","image":"/home/user/photo.jpg"}]}'

# With callback
noctalia-shell ipc call plugin:dmenu showJson '{"items":["a","b","c"],"callbackCmd":"echo {}"}'
```

### `showFromFile` — items from a file

For large lists or pre-built JSON files. Two arguments: file path and options JSON.

The file format is auto-detected: JSON array (`[...]`), JSON config object (`{...}` with `items` key), or plain text (one item per line).

```bash
# Plain text file
noctalia-shell ipc call plugin:dmenu showFromFile /tmp/items.txt '{"prompt":"Select:"}'

# JSON array file
noctalia-shell ipc call plugin:dmenu showFromFile /tmp/items.json '{"prompt":"Pick:"}'
```

### Item object fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display text (required for objects) |
| `value` | string | Return value (defaults to `name`) |
| `description` | string | Subtitle text |
| `icon` | string | [Tabler icon](https://tabler.io/icons) name |
| `image` | string | Absolute path to an image file (overrides `icon`) |

### Options

All options are optional. For `showItems` and `showFromFile`, pass as the second argument. For `showJson`, include in the same object.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `separator` | string | `"\n"` | Delimiter for `showItems` / `showFromFile` text mode |
| `prompt` | string | `""` | Placeholder text in search bar |
| `callbackCmd` | string | `""` | Command on selection. `{}` = value, `{index}` = index, `{name}` = name |
| `resultFile` | string | `/tmp/noctalia-dmenu-result` | Where to write the selection |
| `resultFormat` | string | `"plain"` | `"plain"`, `"json"`, or `"index"` |
| `allowCustomInput` | bool | `false` | Allow typing values not in the list |
| `closeOnSelect` | bool | `true` | Close panel after selection |
| `maxResults` | int | `200` | Maximum items to display |

### Other commands

| Command | Args | Description |
|---------|------|-------------|
| `toggle` | — | Toggle the panel |
| `close` | — | Cancel and close |
| `clear` | — | Reset state without closing |

## Helper script

Pipe-friendly interface, like `rofi -dmenu`.

```bash
echo -e "Power Off\nReboot\nSuspend" | noctalia-dmenu -p "Power:"

CHOICE=$(echo -e "yes\nno" | noctalia-dmenu -p "Continue?")

echo "one::two::three" | noctalia-dmenu -s "::"

noctalia-dmenu -f /tmp/items.txt -p "Select:"

echo -e "Firefox\nChromium" | noctalia-dmenu -cb "gtk-launch {}"
```

| Flag | Description |
|------|-------------|
| `-p`, `--prompt` | Search bar placeholder |
| `-cb`, `--callback` | Command on selection (`{}` = result) |
| `-c`, `--custom` | Allow custom text input |
| `-s`, `--separator` | Item separator (default: newline) |
| `-t`, `--timeout` | Wait timeout in seconds (default: 30) |
| `-r`, `--result-file` | Override result file path |
| `-f`, `--file` | Read items from file |
| `-F`, `--format` | Result format: plain, json, index |
| `-no-close` | Keep panel open after selection |

Exit codes: `0` selected, `1` timeout/cancelled, `2` error.

## Chaining

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

## Settings

Settings → Plugins → Dmenu Provider → Configure.

| Setting | Default | Description |
|---------|---------|-------------|
| Panel position | `follow_launcher` | `follow_launcher`, `center`, `top_center`, `bottom_center`, `top_left`, `top_right`, `bottom_left`, `bottom_right` |
| Show match count | `true` | Filtered/total in footer |
| Show footer | `true` | Result count footer |
| Allow custom input | `false` | Default for custom input |
| Custom input prefix | — | Prefix for custom values |
| Close on select | `true` | Auto-close on selection |
| Show toast | `false` | Notification on selection |
| Result file | `/tmp/noctalia-dmenu-result` | Default result path |
| Default separator | `\n` | Default for showItems |
| Max results | `200` | Display cap |

## Testing

```bash
./test-dmenu.sh       # all 20 tests
./test-dmenu.sh 4     # just one test
```

## License

MIT
