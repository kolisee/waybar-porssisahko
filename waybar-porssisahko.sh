#!/bin/bash

# update waybar module every quarter hour
# crontab -e:
#     */15 0-23 * * * (pkill -SIGRTMIN+21 waybar)

# v1 for hourly prices, v2 for quarterly prices
JSON_API_URL="https://api.porssisahko.net/v2/latest-prices.json"
JSON_FILE="$HOME/.cache/latest-prices.json"
FORMATTED_FILE="$HOME/.cache/latest-prices-formatted"

TODAY=$(date +%F)
TOMORROW=$(date +%F --date='tomorrow')
YESTERDAY=$(date +%F --date='yesterday')
CURRENT_HOUR=$(date +"%H:00")
CURRENT_TIME=$(date +%R)
UPPER_LIMIT=8


# downloader functions

write_formatted()
{
  if ! [ -f "$FORMATTED_FILE" ]; then
    touch "$FORMATTED_FILE"
  fi

  # truncate file
  true > "$FORMATTED_FILE"

  local formatted_price
  formatted_price=()
  while read -r line; do
    ISO_DATE=$(echo "$line" | awk '{print $1}')
    VALUE=$(echo "$line" | awk '{printf "%.3f", $2}')
    LOCAL_DATE=$(date --date="$ISO_DATE" +"%Y-%m-%d %H:%M")
    formatted_price+=("$LOCAL_DATE $VALUE")
  done <<<"$(jq -r '.prices[] | "\(.startDate) \(.price)"' $JSON_FILE)"

  # reverse array
  local array_index
  array_index=$((${#formatted_price[@]}-1))
  for element in "${formatted_price[@]}"; do
    formatted_price_reversed[$((array_index--))]="$element"
  done

  # lump quarterly prices together
  local day hour lump_index
  lump_index=0
  declare -A formatted_price_lumped
  for element in "${formatted_price_reversed[@]}"; do
    day=${element:8:2}
    hour=${element:11:2}
    current_index_len=${#formatted_price_lumped[$lump_index]}
    if ((${#formatted_price_lumped[$lump_index]} == 0)); then
      formatted_price_lumped[$lump_index]="$element"
    elif [[ ${formatted_price_lumped[$lump_index]:11:2} =~ "$hour" ]] && ((current_index_len < 43)); then
      formatted_price_lumped[$lump_index]="${formatted_price_lumped[$lump_index]} ${element:17}"
    else
      lump_index=$((lump_index + 1))
      formatted_price_lumped[$lump_index]="$element"
    fi
  done

  for i in $(seq 0 ${#formatted_price_lumped[@]}); do echo "${formatted_price_lumped[$i]}" >> "$FORMATTED_FILE"; done
}

check_updates()
{
  local latest_startDate modded_day modded_hour current_hour
  # check json file: date modified
  modded_day=$(date -d "$(stat -c "%y" "$JSON_FILE")" +"%F")
  modded_hour=$(date -d "$(stat -c "%y" "$JSON_FILE")" +"%-H")
  current_hour=$(date +"%-H")
  current_minutes=$(date +"%-M")
  latest_startDate=$(jq -r '.prices.[0].startDate' "$JSON_FILE" | awk -F'[-T:]' '{ printf "%s-%s-%s\n", $1,$2,$3 }')
  if ! [ -f "$JSON_FILE" ] || ! [ -f "$FORMATTED_FILE" ]; then
    download_and_format
  # if unset or empty string
  elif [ -z ${latest_startDate:+x} ] || [[ $latest_startDate = "$YESTERDAY" ]]; then
    download_and_format
  # current json from today before 2pm, new available today after 2pm
  elif [[ $modded_day = "$TODAY" ]] && ((modded_hour < 14)) && ((current_hour >= 14)) && ((current_minutes >= 15)); then
    download_and_format
  # current json from yesterday, new available today after 2pm
  elif [[ $modded_day = "$YESTERDAY" ]] && ((current_hour >= 14)) && ((current_minutes >= 15)); then
    download_and_format
  # current json from yesterday before 2pm
  elif [[ $modded_day = "$YESTERDAY" ]] && ((modded_hour < 14)); then
    download_and_format
  # current json from at least nudiustertian
  elif [[ ! $modded_day = "$TODAY" ]] && [[ ! $modded_day = "$YESTERDAY" ]]; then
    download_and_format
  fi
}

download_and_format()
{
  echo '{ "text": "fetching.." }'
  curl -s $JSON_API_URL | jq . > "$JSON_FILE"
  write_formatted
}

# parser functions

clamp_to_hex()
{
  local value hex
  value=$1
  if ((value <= 0)); then
    echo "00"
  elif ((value >= 255)); then
    echo "FF"
  else
    hex=$(echo "obase=16; $value" | bc)
    if ((value < 16)); then
      echo "0$hex"
    else
      echo "$hex"
    fi
  fi
}

value_to_color()
{
  local val_int red_raw blue_raw green_raw red green blue
  val_int=$(echo "scale=0; $1 / 1" | bc)
  red_raw=$(echo "$val_int * $UPPER_LIMIT * 4" | bc)
  blue_raw=0
  green_raw=$(echo "255 - (($val_int - $UPPER_LIMIT) * $UPPER_LIMIT * 4)" | bc)
  red=$(clamp_to_hex "$red_raw")
  green=$(clamp_to_hex "$green_raw")
  blue=$(clamp_to_hex "$blue_raw")
  echo "#$red$green$blue"
}

add_current_value_brackets()
{
  local string current_value_occurrence
  string=$1
  if [[ $string =~ $TODAY ]] && [[ $string =~ $CURRENT_HOUR ]]; then
    current_value_occurrence=$(quartertime_to_occurrence "$string")
    if ((current_value_occurrence > 0)); then
      # replace Nth occurrence with sed to avoid multiple replacements
      string=$(echo "$string" | sed -E "s/ (<span color='#[0-9A-F]*'>-?[[:digit:]]+\.[[:digit:]]{3}<\/span>) /[\1]/$current_value_occurrence")
    fi
  fi
  if [[ $string =~ $TOMORROW ]] && [[ $string =~ "00:00" ]]; then
    string=$(echo "$string" | sed "s/\(^.\)/\\n\1/")
  fi
  echo "$string"
}

add_color()
{
  local values color string current_value_occurrence
  string=$1
  values=$(echo "$string" | grep -Eo "\-?[[:digit:]]+\.[[:digit:]]{3}")
  current_value_occurrence=$(quartertime_to_occurrence "$string")
  for value in $values; do
    color=$(value_to_color $value)
    string=$(echo "$string" | sed -E "s/($value)/<span color='$color'>\1<\/span>/g")
  done
  if [[ $string =~ $TODAY ]] && [[ $string =~ $CURRENT_HOUR ]] && ((current_value_occurrence > 0)); then
    # replace Nth occurrence with sed to avoid multiple replacements
    string=$(echo "$string" | sed -E "s/ (<span color='#[0-9A-F]*'>-?[[:digit:]]+\.[[:digit:]]{3}<\/span>) /[\1]/$current_value_occurrence")
  fi
  if [[ $string =~ $TOMORROW ]] && [[ $string =~ "00:00" ]]; then
    string=$(echo "$string" | sed "s/\(^.\)/\\n\1/")
  fi
  echo "$string"
}

quartertime_to_occurrence()
{
  local value minutes
  values=$(echo $1 | grep -Eo "\-?[[:digit:]]+\.[[:digit:]]{3}")
  minutes=${CURRENT_TIME:3:2}

  case $minutes in
    0[0-9] | 1[0-4])
    echo "1"
    ;;
    1[5-9] | 2[0-9])
    echo "2"
    ;;
    3[0-9] | 4[0-4])
    echo "3"
    ;;
    4[5-9] | 5[0-9])
    echo "4"
    ;;
    *)
    echo "1"
    ;;
  esac
}

# obsolete, unused
time_to_quartertime()
{
  local time minutes
  time=$($1)
  minutes=${time:3:2}

  case $minutes in
    0[0-9] | 1[0-4])
    echo "${time:0:2}:00"
    ;;
    1[5-9] | 2[0-9])
    echo "${time:0:2}:15"
    ;;
    3[0-9] | 4[0-4])
    echo "${time:0:2}:30"
    ;;
    4[5-9] | 5[0-9])
    echo "${time:0:2}:45"
    ;;
    *)
    echo "$time"
    ;;
  esac
}

get_current_quarterly_value_from_line()
{
  local values minutes
  values=$(echo $1 | grep -Eo "\-?[[:digit:]]+\.[[:digit:]]{3}")
  minutes=${CURRENT_TIME:3:2}

  case $minutes in
    0[0-9] | 1[0-4])
    echo $values | awk '{print $1}'
    ;;
    1[5-9] | 2[0-9])
    echo $values | awk '{print $2}'
    ;;
    3[0-9] | 4[0-4])
    echo $values | awk '{print $3}'
    ;;
    4[5-9] | 5[0-9])
    echo $values | awk '{print $4}'
    ;;
    *)
    echo $values | awk '{print $1}'
    ;;
  esac
}

# main

while : ; do
  if timeout 10 true >/dev/tcp/8.8.8.8/53; then
    echo '{ "text": "checking.." }'
    check_updates
    break
  else
    echo '{ "text": "looping.." }'
    sleep 10s
  fi
done

echo '{ "text": "parsing.." }'

FORMATTED_FILE_OUTPUT=$(cat "$FORMATTED_FILE")

# today
TODAY_PRICES=($(echo "$FORMATTED_FILE_OUTPUT" | grep "$TODAY" | awk '{print $3 + $4 + $5 + $6}'))

for e in "${TODAY_PRICES[@]}"; do
  TODAY_TOTAL_PRICE=$(echo "$TODAY_TOTAL_PRICE" "$e" | awk '{print $1 + $2}')
done

TODAY_AVG_PRICE=$(echo "$TODAY_TOTAL_PRICE" "${#TODAY_PRICES[@]}" | awk '{printf "%.3f", $1 / ($2 * 4)}')
TODAY_AVG_PRICE="Today avg   : <span color='$(value_to_color "$TODAY_AVG_PRICE")'>$TODAY_AVG_PRICE</span> c/kWh (${#TODAY_PRICES[@]}h)"
if [ -x "$(command -v waybar-porssisahko)" ]; then
  TOOLTIP_FORMAT=$(waybar-porssisahko "$FORMATTED_FILE" | \
                  grep -E "$TODAY|$TOMORROW" | \
                  awk '{print $0 "_c/kWh"}' | \
                  column -R0 -t -s '_' -o '  ' | \
                  while read line ; do add_current_value_brackets "$line" ; done )
else
  TOOLTIP_FORMAT=$(cat "$FORMATTED_FILE" | \
                  grep -E "$TODAY|$TOMORROW" | \
                  awk '{print $0 "  c/kWh"}' | \
                  column -R0 -t -o '  ' | \
                  while read line ; do add_color "$line" ; done )
fi

LINE_MAX_LEN=$(awk 'length > max_length { max_length = length; longest_line = $0 } END { print longest_line " c/kWh" }' "$FORMATTED_FILE")
COLUMN_HEADER=$(echo "$LINE_MAX_LEN" | column -t -N Date,Time,HH:00,HH:15,HH:30,HH:45,Price -R3-6 | head -n 1)

# tomorrow
TOMORROW_PRICES=($(echo "$FORMATTED_FILE_OUTPUT" | grep "$TOMORROW" | awk '{print $3 + $4 + $5 + $6}'))
if ((${#TOMORROW_PRICES[@]} > 0)); then
  for e in "${TOMORROW_PRICES[@]}"; do
    TOMORROW_TOTAL_PRICE=$(echo "$TOMORROW_TOTAL_PRICE" "$e" | awk '{print $1 + $2}')
  done
  TOMORROW_AVG_PRICE=$(echo "$TOMORROW_TOTAL_PRICE" "${#TOMORROW_PRICES[@]}" | awk '{printf "%.3f", $1 / ($2 * 4)}')
  TOMORROW_AVG_PRICE="Tomorrow avg: <span color='$(value_to_color "$TOMORROW_AVG_PRICE")'>$TOMORROW_AVG_PRICE</span> c/kWh (${#TOMORROW_PRICES[@]}h)"
  TOOLTIP_FORMAT="$TODAY_AVG_PRICE\n$TOMORROW_AVG_PRICE\n\n<u>$COLUMN_HEADER</u>\n$TOOLTIP_FORMAT"
fi

CURRENT=$(echo "$FORMATTED_FILE_OUTPUT" | \
          grep -E "${TODAY}[[:space:]]+${CURRENT_HOUR}" | \
          while read line ; do get_current_quarterly_value_from_line "$line" ; done)
COLOR=$(value_to_color "$CURRENT")
CURRENT="<span color='${COLOR}'>${CURRENT}</span> c/kWh"

printf '{ "text":"%s","tooltip":"%s" }' "$CURRENT" "$TOOLTIP_FORMAT" | awk '{printf "%s\\n", $0}'
