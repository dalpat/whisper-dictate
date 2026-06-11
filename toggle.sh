#!/bin/bash

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE=/tmp/whisper_rec.pid
WAVFILE=/tmp/whisper_input.wav
INDICATOR_PIDFILE=/tmp/whisper_indicator.pid
STREAM_PIDFILE=/tmp/whisper_stream.pid
STREAM_TXT=/tmp/whisper_stream.txt
SNAPSHOT=/tmp/whisper_snapshot.wav
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

kill_stream() {
    if [ -f "$STREAM_PIDFILE" ]; then
        kill "$(cat "$STREAM_PIDFILE")" 2>/dev/null
        rm -f "$STREAM_PIDFILE"
    fi
}

cleanup_stream() {
    rm -f "$STREAM_TXT" "$SNAPSHOT"
}

# Fix WAV header sizes after snapshotting a still-growing file
# WAV header: bytes 4-7 = RIFF size, bytes 40-43 = data size
fix_wav_header() {
    local file="$1"
    local size
    size=$(stat -c%s "$file") || return 1
    [ "$size" -le 44 ] && return 1

    local riff_size=$((size - 8))
    local data_size=$((size - 44))

    printf '\%03o\%03o\%03o\%03o' \
        $((riff_size & 0xFF)) \
        $(((riff_size >> 8) & 0xFF)) \
        $(((riff_size >> 16) & 0xFF)) \
        $(((riff_size >> 24) & 0xFF)) \
        | dd of="$file" bs=1 seek=4 count=4 conv=notrunc 2>/dev/null

    printf '\%03o\%03o\%03o\%03o' \
        $((data_size & 0xFF)) \
        $(((data_size >> 8) & 0xFF)) \
        $(((data_size >> 16) & 0xFF)) \
        $(((data_size >> 24) & 0xFF)) \
        | dd of="$file" bs=1 seek=40 count=4 conv=notrunc 2>/dev/null
}

# ── Streaming transcription loop ────────────────────────────────────────────
stream_loop() {
    local last_text=""
    while [ -f "$PIDFILE" ]; do
        # Snapshot the live WAV to avoid read-while-write issues
        if [ -f "$WAVFILE" ] && [ -s "$WAVFILE" ]; then
            cp "$WAVFILE" "$SNAPSHOT" 2>/dev/null
            fix_wav_header "$SNAPSHOT"
        else
            sleep 0.5
            continue
        fi

        # Run whisper-cli on snapshot (suppress noise)
        TEXT=$("$WHISPER_BIN" -m "$MODEL" -f "$SNAPSHOT" -nt -np -sns \
            -nth 0.7 -et 2.0 2>/dev/null \
            | grep -v '^\[' | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        rm -f "$SNAPSHOT"

        if [ -n "$TEXT" ]; then
            # Write full text for indicator to display
            echo "$TEXT" > "$STREAM_TXT"

            # Dedup: only type the new portion via ydotool
            if [ "$TEXT" != "$last_text" ]; then
                NEW_PART="${TEXT#"$last_text"}"
                if [ -n "$NEW_PART" ]; then
                    echo -n "$NEW_PART" | ydotool type -f - 2>/dev/null
                fi
                last_text="$TEXT"
            fi
        fi

        sleep 1.5
    done
}

if [ -f "$PIDFILE" ]; then
    # ── Stop recording ──────────────────────────────────────────────────────
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.2

    kill_stream
    kill_indicator

    if [ ! -f "$WAVFILE" ] || [ ! -s "$WAVFILE" ]; then
        notify-send -t 3000 "Whisper" "No audio captured"
        cleanup_stream
        exit 0
    fi

    # Final transcription on complete audio
    TEXT=$("$WHISPER_BIN" -m "$MODEL" -f "$WAVFILE" -nt -np -sns \
        -nth 0.7 -et 2.0 2>/dev/null \
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
    cleanup_stream
else
    # ── Start recording ─────────────────────────────────────────────────────
    pw-record --format s16 --rate 16000 --channels 1 "$WAVFILE" &
    echo $! > "$PIDFILE"

    # Start streaming loop in background
    stream_loop &
    echo $! > "$STREAM_PIDFILE"

    if [ -x "$INDICATOR" ]; then
        "$INDICATOR" "Listening..." stream &
        echo $! > "$INDICATOR_PIDFILE"
    else
        notify-send -t 60000 "Whisper" "🎙 Listening..."
    fi
fi
