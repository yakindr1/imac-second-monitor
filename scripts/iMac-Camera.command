#!/bin/bash
set -u
umask 077
pc_ip="192.168.50.1"
mac_ip="192.168.50.2"
ethernet_interface="en0"
camera_input="0:none"
root="$HOME/Library/Application Support/Codex-iMac-Camera"
cache="$HOME/Library/Caches/Codex-iMac-Camera"
mkdir -p "$cache" || exit 1
[ -x "$root/bin/ffmpeg" ] || { printf 'Поместите проверенный FFmpeg в папку bin и разрешите его запуск.\n'; exit 1; }
pidfile="$cache/launcher.pid"
if [ -f "$pidfile" ]; then
    previous=$(cat "$pidfile")
    if [[ "$previous" =~ ^[0-9]+$ ]] && ps -p "$previous" -o command= | grep -Fq "$root/iMac-Camera.command"; then
        printf 'Камера уже запущена.\n'
        exit 0
    fi
fi
route -n get "$pc_ip" | grep -Eq "interface:[[:space:]]+$ethernet_interface$" || { printf 'Проверьте сетевой кабель и ethernet_interface в скрипте.\n'; exit 1; }
ifconfig "$ethernet_interface" | grep -Fq "inet $mac_ip " || { printf 'Проверьте проводной адрес Mac в скрипте.\n'; exit 1; }
printf '%s\n' "$$" > "$pidfile"
child=
cleanup() {
    trap - EXIT INT TERM
    if [ -n "$child" ]; then
        kill -TERM "$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
    fi
    rm -f "$pidfile"
}
trap 'exit 0' INT TERM
trap cleanup EXIT
printf 'Камера iMac для ПК. Разрешите Терминалу доступ к камере.\n'
printf 'Остановка: Ctrl+C в этом окне.\n'
while true; do
    "$root/bin/ffmpeg" -hide_banner -loglevel warning -nostats \
        -f avfoundation -framerate 29.97 -video_size 1280x720 \
        -pixel_format uyvy422 -i "$camera_input" -an \
        -c:v mjpeg -q:v 4 -threads 2 -pix_fmt yuvj420p \
        -flush_packets 1 -f nut \
        "tcp://$mac_ip:5000?listen=1&tcp_nodelay=1" \
        2> "$cache/camera.log" &
    child=$!
    wait "$child"
    result=$?
    child=
    [ "$result" -ne 0 ] || break
    if ! grep -Eq 'Broken pipe|Connection reset by peer' "$cache/camera.log"; then
        cat "$cache/camera.log"
        exit "$result"
    fi
    sleep 1
done
