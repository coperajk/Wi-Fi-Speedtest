#!/bin/bash

#-----------------------------------------
# Speed Test Script for R36S on ArkOS AeUX
#-----------------------------------------

# get all needed sudo permissions
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

CURR_TTY="/dev/tty1"
sudo chmod 666 $CURR_TTY
reset

# hide cursor and clear
printf "\e[?25l" > $CURR_TTY
dialog --clear

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz

# kill potentially interfering processes
pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9
echo "Starting WiFi Speedtest script..." > $CURR_TTY
# UI
WIFI_STATUS=$(nmcli radio wifi)
BACKTITLE="WiFi Speedtest by coperajk"
if [[ "$WIFI_STATUS" == "enabled" ]]; then
    TITLE="Wi-Fi: Enabled"
else
    TITLE="Wi-Fi: Disabled."
fi

# exit function
exit_script() {
    printf "\e[?25h" > "$CURR_TTY"
    printf "\033c" > "$CURR_TTY"
    if [[ ! -z $(pgrep -f gptokeyb) ]]; then
        pgrep -f gptokeyb | sudo xargs kill -9
    fi
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
    fi
    pkill -f "gptokeyb -1 Wi-Fi Speedtest.sh" || true
    exit 0
}

# speedtest download function
run_speedtest() {
    local file_url=$1
    local label=$2

    dialog --infobox "Running speed test with $label file..." 3 40 > "$CURR_TTY"
    sleep 1

    START=$(date +%s%N)
    wget -O /dev/null "$file_url" > /dev/null 2>&1
    END=$(date +%s%N)

    DURATION_NS=$((END - START))
    DURATION_S=$(awk "BEGIN { printf \"%.1f\", $DURATION_NS / 1000000000 }")
    SIZE_MB=$(echo "$label" | tr -d 'MB')
    SPEED_MBPS=$(awk "BEGIN { printf \"%.2f\", $SIZE_MB / $DURATION_S }")

    dialog --msgbox "Download completed!\n\nFile: $label\nTime: ${DURATION_S} s\nSpeed: ${SPEED_MBPS} MB/s" 10 40 > "$CURR_TTY"
    printf "\033c" > "$CURR_TTY"
}


# main menu
MainMenu() {
    while true; do
        menu_opts=(dialog \
            --backtitle "$BACKTITLE" \
            --title "WiFi Speedtest - $TITLE" \
            --clear \
            --cancel-label "Exit" \
            --menu "Select file size for test:" 15 50 10)

        choices=(
            1 "Speedtest with 10MB file"
            2 "Speedtest with 20MB file"
            3 "Speedtest with 50MB file"
        )

        selection=$("${menu_opts[@]}" "${choices[@]}" 2>&1 > "$CURR_TTY")

        if [[ $? != 0 ]]; then
            exit_script
        fi

        case $selection in
            1) run_speedtest "http://ipv4.download.thinkbroadband.com/10MB.zip" "10MB" ;;
            2) run_speedtest "http://ipv4.download.thinkbroadband.com/20MB.zip" "20MB" ;;
            3) run_speedtest "http://ipv4.download.thinkbroadband.com/50MB.zip" "50MB" ;;
        esac
    done
}

# setup gptokeyb controller input
sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb > /dev/null && pgrep -f gptokeyb | sudo xargs kill -9
/opt/inttools/gptokeyb -1 "Wi-Fi Speedtest.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

# clear terminal 
printf "\033c" > $CURR_TTY
dialog --clear

trap exit_script EXIT SIGINT SIGTERM

# launch the main menu
MainMenu
