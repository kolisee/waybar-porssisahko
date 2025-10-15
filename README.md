# Waybar pörssisähkö module
Shows current price in c/kWh, tooltip shows 48h prices.

Refreshes itself when clicked.

Recommended to compile waybar-porssisahko.c for that extra parsing speed (bash arithmetics is slow).

API json from URL gets updated daily (2PM EET). Script downloads new json automatically.

## Requirements
- GNU/Linux
- Waybar
- Internet connection
- command-line utilities: jq
- gcc for compiling

## Installation
Compile `waybar-porssisahko.c` with gcc:
- `gcc waybar-porssisahko.c -o waybar-porssisahko`
- put the executable inside any of your $PATH directories

Download/copy `waybar-porssisahko.sh`
- put it in your script folder (mine is `~/Documents/scripts/waybar-porssisahko.sh`)

Add module to config.jsonc (`~/.config/waybar/config.jsonc`):
- change exec
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

Automatically update waybar module every quarter hour with cronjob:
- run `crontab -e`
- add `*/15 0-23 * * * (pkill -SIGRTMIN+21 waybar)`
- save and exit

Change `"signal": 21` and `-SIGRTMIN+21` if needed.