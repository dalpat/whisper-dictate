#!/bin/bash

PIDFILE=/tmp/whisper_rec.pid
WAVFILE=/tmp/whisper_input.wav
WHISPER_BIN="$HOME/whisper.cpp/build/bin/whisper-cli"
WHISPER_MODEL="${WHISPER_MODEL:-tiny.en}"  # override: WHISPER_MODEL=base.en
MODEL="$HOME/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin"
NOTIF_ID=8472

if [ -f "$PIDFILE" ]; then
    kill "$(cat $PIDFILE)" 2>/dev/null && rm "$PIDFILE"
    sleep 0.2

    TEXT=$("$WHISPER_BIN" -m "$MODEL" -f "$WAVFILE" -nt -np 2>/dev/null \
        | grep -v '^\[' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -n "$TEXT" ]; then
        echo -n "$TEXT" | wl-copy
        notify-send -r $NOTIF_ID "Whisper" "✓ $TEXT" -t 8000
    else
        notify-send -r $NOTIF_ID "Whisper" "No speech detected" -t 3000
    fi

    rm -f "$WAVFILE"
else
    arecord -f S16_LE -r 16000 -c 1 -q "$WAVFILE" &
    echo $! > "$PIDFILE"
    notify-send -r $NOTIF_ID "Whisper" "🎙 Listening..." -t 60000
fi
