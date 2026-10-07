export LC_ALL=C
runtime="${XDG_RUNTIME_DIR:?}/voxtype"
exec 9>"$runtime/microphone.lock"
flock -n 9 || exit 0

recording() {
  local state
  state=$(cat "$runtime/state" 2>/dev/null) || return 1
  [[ "$state" == recording || "$state" == streaming ]]
}

recording || exit 0
pid=$(cat "$runtime/pid")
source=$(pactl get-default-source)
mute=$(pactl get-source-mute "$source")
[[ "$mute" == "Mute: yes" ]] || exit 0

restore() {
  if ! pactl set-source-mute "$source" 1; then
    notify-send -u critical "Voxtype" "Could not restore microphone mute. Please mute it manually." || true
  fi
}
trap restore EXIT
trap 'exit 0' HUP INT TERM

# Pin the source: a default-device change must not mute a different microphone.
if ! pactl set-source-mute "$source" 0; then
  notify-send -u critical "Voxtype" "Microphone is muted and could not be unmuted." || true
  exit 1
fi

# ponytail: polling restores mute within 100 ms; use state events if that matters.
deadline=$((SECONDS + ${1:?Maximum recording duration required} + 1))
while recording && kill -0 "$pid" 2>/dev/null && ((SECONDS < deadline)); do
  sleep 0.1
done
