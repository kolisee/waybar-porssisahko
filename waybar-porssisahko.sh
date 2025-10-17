#!/bin/sh

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
exit 0
UPPER_LIMIT=8

# downloader functions

write_formatted()
{
  if ! [ -f "$FORMATTED_FILE" ]; then
    touch $FORMATTED_FILE
  fi

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
  local day hour
  declare -A formatted_price_lumped
  for element in "${formatted_price_reversed[@]}"; do
    day=$(echo ${element:8:2})
    hour=$(echo ${element:11:2})
    if ((${#formatted_price_lumped["$day$hour"]} == 0)); then
      formatted_price_lumped["$day$hour"]="$element"
    else
      formatted_price_lumped["$day$hour"]="${formatted_price_lumped["$day$hour"]} ${element:16}"
    fi
  done
  
  printf "%s\n" "${formatted_price_lumped[@]}" | sort -n -k12 > $FORMATTED_FILE
}

check_updates()
{
  local latest_startDate latest now modded_day modded_hour current_hour
  # check json file: date modified
  modded_day=$(date -d "$(stat -c "%y" $JSON_FILE)" +"%F")
  modded_hour=$(date -d "$(stat -c "%y" $JSON_FILE)" +"%-H")
  current_hour=$(date +"%-H")
  latest_startDate=$(jq -r '.prices.[0].startDate' $JSON_FILE | awk -F'[-T:]' '{ printf "%s-%s-%s\n", $1,$2,$3 }')
  if ! [ -f "$JSON_FILE" ] || ! [ -f "$FORMATTED_FILE" ]; then
    download_and_format
  # if unset or empty string
  elif [ -z ${latest_startDate:+x} ]; then
    download_and_format
  # current json from today before 2pm, new available today after 2pm
  elif [[ $modded_day = $TODAY ]] && (($modded_hour < 14)) && ((current_hour >= 14)); then
    download_and_format
  # current json from yesterday, new available today after 2pm
  elif [[ $modded_day = $YESTERDAY ]] && ((current_hour >= 14)); then
    download_and_format
  # current json from yesterday before 2pm
  elif [[ $modded_day = $YESTERDAY ]] && (($modded_hour < 14)); then
    download_and_format
  # current json from at least nudiustertian
  elif [[ ! $modded_day = $TODAY ]] && [[ ! $modded_day = $YESTERDAY ]]; then
    download_and_format
  fi
}

download_and_format()
{
  echo '{ "text": "fetching.." }'
  curl -s $JSON_API_URL | jq . > $JSON_FILE
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
      echo $hex
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
  red=$(clamp_to_hex $red_raw)
  green=$(clamp_to_hex $green_raw)
  blue=$(clamp_to_hex $blue_raw)
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
  echo "$string"
}

add_color()
{
  local values color string current_value current_value_occurrence
  string=$1
  values=$(echo $string | grep -Eo "\-?[[:digit:]]+\.[[:digit:]]{3}")
  current_value=$(get_current_quarterly_value_from_line "$string")
  current_value_occurrence=$(quartertime_to_occurrence "$string")
  for value in $values; do
    color=$(value_to_color $value)
    string=$(echo "$string" | sed -E "s/($value)/<span color='$color'>\1<\/span>/g")
  done
  if [[ $string =~ $TODAY ]] && [[ $string =~ $CURRENT_HOUR ]] && ((current_value_occurrence > 0)); then
    # replace Nth occurrence with sed to avoid multiple replacements
    string=$(echo "$string" | sed -E "s/ (<span color='#[0-9A-F]*'>-?[[:digit:]]+\.[[:digit:]]{3}<\/span>) /[\1]/$current_value_occurrence")
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
    echo "0"
    ;;
  esac
}

# obsolete, unused
time_to_quartertime()
{
  local time minutes
  time=$(echo $1)
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
    echo "$1"
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

# today
TODAY_PRICES=($(cat $FORMATTED_FILE | grep "$TODAY" | awk '{print $3 + $4 + $5 + $6}'))

for e in "${TODAY_PRICES[@]}"; do
  TODAY_TOTAL_PRICE=$(echo "$TODAY_TOTAL_PRICE" "$e" | awk '{print $1 + $2}')
done

TODAY_AVG_PRICE=$(echo "$TODAY_TOTAL_PRICE" "${#TODAY_PRICES[@]}" | awk '{printf "%.3f", $1 / ($2 * 4)}')
TODAY_AVG_PRICE="Today avg   : <span color='$(value_to_color $TODAY_AVG_PRICE)'>$TODAY_AVG_PRICE</span> c/kWh"

if [ -x "$(command -v waybar-porssisahko)" ]; then
  TODAY_HOURLY_FORMAT=$(waybar-porssisahko $FORMATTED_FILE | \
                      grep "$TODAY" | \
                      awk '{print $0 "_c/kWh"}' | \
                      column -R0 -t -s '_' -o '  ' | \
                      while read line ; do add_current_value_brackets "$line" ; done )
else
  TODAY_HOURLY_FORMAT=$(cat $FORMATTED_FILE | \
                    grep "$TODAY" | \
                    awk '{print $0 "  c/kWh"}' | \
                    column -R0 -t -o '  ' | \
                    while read line ; do add_color "$line" ; done )
fi
TOOLTIP_HOURLY=$TODAY_HOURLY_FORMAT

# tomorrow
TOMORROW_PRICES=($(cat $FORMATTED_FILE | grep "$TOMORROW" | awk '{print $3 + $4 + $5 + $6}'))
if ((${#TOMORROW_PRICES[@]} > 0)); then
  for e in "${TOMORROW_PRICES[@]}"; do
    TOMORROW_TOTAL_PRICE=$(echo "$TOMORROW_TOTAL_PRICE" "$e" | awk '{print $1 + $2}')
  done

  TOMORROW_AVG_PRICE=$(echo "$TOMORROW_TOTAL_PRICE" "${#TOMORROW_PRICES[@]}" | awk '{printf "%.3f", $1 / ($2 * 4)}')
  TOMORROW_AVG_PRICE="Tomorrow avg: <span color='$(value_to_color $TOMORROW_AVG_PRICE)'>$TOMORROW_AVG_PRICE</span> c/kWh"

  if [ -x "$(command -v waybar-porssisahko)" ]; then
    TOMORROW_HOURLY_FORMAT=$(waybar-porssisahko $FORMATTED_FILE | \
                          grep "$TOMORROW" | \
                          awk '{print $0 "_c/kWh"}' | \
                          column -R0 -t -s '_' -o '  ')
  else
    TOMORROW_HOURLY_FORMAT=$(cat $FORMATTED_FILE | \
                          grep "$TOMORROW" | \
                          awk '{print $0 "  c/kWh"}' | \
                          column -R0 -t -o '  ' | \
                          while read line ; do add_color "$line" ; done )
  fi

  TOOLTIP_HOURLY="$TODAY_AVG_PRICE\n$TOMORROW_AVG_PRICE\n\n$TOOLTIP_HOURLY\n\n$TOMORROW_HOURLY_FORMAT"
fi

CURRENT=$(cat $FORMATTED_FILE | grep -E "$TODAY[[:space:]]+$CURRENT_HOUR" | while read line ; do get_current_quarterly_value_from_line "$line" ; done)
COLOR=$(value_to_color "$CURRENT")
CURRENT=$(echo "<span color='$COLOR'>$CURRENT</span> c/kWh")

printf '{ "text":"%s","tooltip":"%s" }' "$CURRENT" "$TOOLTIP_HOURLY" | awk '{printf "%s\\n", $0}'
