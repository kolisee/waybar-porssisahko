# Waybar module for SDAC electricity spot prices
Displays current price in c/kWh, tooltip shows all prices and daily averages.

API json from URL gets updated daily (2PM EET). Script downloads new json automatically when needed.

Fetched from [https://porssisahko.net/](https://porssisahko.net/)

API URL: [https://api.porssisahko.net/v2/latest-prices.json](https://api.porssisahko.net/v2/latest-prices.json)

## Requirements
- GNU/Linux
- Waybar
- Internet connection
- command-line utilities: jq
- gcc for compiling (optional, recommended)

## Installation

Download/copy `waybar-porssisahko.sh`
- put it in your script directory (mine is `~/Documents/scripts/waybar-porssisahko.sh`)

Add module to config.jsonc (`~/.config/waybar/config.jsonc`):
```
"custom/porssisahko": {
        "restart-interval": 3600,
        "format": "{} ",
        "return-type": "json",
        "tooltip": true,
        "exec": "~/Documents/scripts/waybar-porssisahko.sh",
        "exec-if": "exit 0", // always run; consider advanced run conditions
        "on-click-release": "pkill -SIGRTMIN+21 waybar",
        "signal": 21
    },
```
- change exec path
- restart-interval is 1 hour because I intended to use cronjob for precise module update

Automatically update waybar module every quarter hour with cronjob:
- run `crontab -e`
- add `*/15 0-23 * * * (pkill -SIGRTMIN+21 waybar)`
- save and exit

Change `"signal": 21` and `-SIGRTMIN+21` if needed.

(Optional) Compile `waybar-porssisahko.c` with gcc:
- `gcc waybar-porssisahko.c -o waybar-porssisahko`
- put the executable inside any of your $PATH directories
