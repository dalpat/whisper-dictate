#!/bin/bash

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE=/tmp/whisper_rec.pid
WAVFILE=/tmp/whisper_input.wav
INDICATOR_PIDFILE=/tmp/whisper_indicator.pid
WHISPER_BIN="$HOME/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL="${WHISPER_MODEL:-tiny.en}"
MODEL="$HOME/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin"
INDICATOR="$SCRIPT_DIR/indicator"

# Ensure ydotool daemon is running
pgrep -x ydotoold >/dev/null 2>&1 || ydotoold &>/dev/null &
sleep 0.2

kill_indicator() {
    if [ -f "$INDICATOR_PIDFILE" ]; then
        kill "$(cat "$INDICATOR_PIDFILE")" 2>/dev/null
        rm -f "$INDICATOR_PIDFILE"
    fi
}

if [ -f "$PIDFILE" ]; then
    # ── Stop recording ──────────────────────────────────────────────────────
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.2

    kill_indicator

    if [ ! -f "$WAVFILE" ] || [ ! -s "$WAVFILE" ]; then
        notify-send -t 3000 "Whisper" "No audio captured"
        exit 0
    fi

    TEXT=$("$WHISPER_BIN" -m "$MODEL" -f "$WAVFILE" -nt -np 2>/dev/null \
        | grep -v '^\[' | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -n "$TEXT" ]; then
        echo -n "$TEXT" | wl-copy
        sleep 0.3
        echo -n "$TEXT" | ydotool type -f - 2>/dev/null
        if [ -x "$INDICATOR" ]; then
            "$INDICATOR" "$TEXT" result &
        else
            notify-send -t 4000 "Whisper" "✓ $TEXT"
        fi
    else
        notify-send -t 3000 "Whisper" "No speech detected"
    fi

    rm -f "$WAVFILE"
else
    # ── Start recording ─────────────────────────────────────────────────────
    arecord -f S16_LE -r 16000 -c 1 -q "$WAVFILE" &
    echo $! > "$PIDFILE"

    if [ -x "$INDICATOR" ]; then
        "$INDICATOR" "Listening..." &
        echo $! > "$INDICATOR_PIDFILE"
    else
        notify-send -t 60000 "Whisper" "🎙 Listening..."
    fi
fi
