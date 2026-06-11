# whisper-dictate

Offline voice dictation for Linux (GNOME/Wayland). Press a hotkey to start recording — text streams live into the overlay and auto-types into your focused app as you speak.

Built on [whisper.cpp](https://github.com/ggml-org/whisper.cpp). No cloud, no subscription, no internet required after setup.

## Requirements

- Ubuntu/Debian-based Linux
- GNOME desktop (Wayland)
- Microphone
- PipeWire (for audio capture via `pw-record`)
- `libgtk-3-dev` (for building the indicator overlay)
- `ydotool` (for auto-typing transcribed text)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/dalpat/whisper-dictate/main/get.sh | bash
```

That's it. Installs dependencies, builds whisper.cpp, downloads the model, and registers the hotkey automatically.

Custom hotkey (default is `Super+Alt+R`):

```bash
curl -fsSL https://raw.githubusercontent.com/dalpat/whisper-dictate/main/get.sh | bash -s "<Super><Alt>d"
```

Custom model:

```bash
WHISPER_MODEL=base.en bash <(curl -fsSL https://raw.githubusercontent.com/dalpat/whisper-dictate/main/get.sh)
```

## Usage

| Action | Result |
|--------|--------|
| Press hotkey | Toast overlay with animated waves appears, streaming begins |
| Speak | Text appears live in the overlay, auto-types into focused app |
| Press hotkey again | Final transcription shown, text copied to clipboard |
| `Ctrl+V` | Also available — text is copied to clipboard too |

## Model Configuration

The default model is `tiny.en` (fast, English-only, ~75MB). To use a different model:

```bash
# one-time
WHISPER_MODEL=base.en ./install.sh

# or export in ~/.bashrc for permanent change
export WHISPER_MODEL=base.en
```

Available models (English):

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| `tiny.en` | 75MB | fastest | good |
| `base.en` | 142MB | fast | better |
| `small.en` | 466MB | slow | best |

Multilingual models (without `.en`) also work if you need other languages.

## How it works

- `toggle.sh` — the hotkey script. Records audio via `pw-record` (PipeWire), runs streaming transcription loop with `whisper-cli`, copies result with `wl-copy`
- `indicator.c` — compiled GTK3 toast overlay. Shows animated waves with live transcription during recording, auto-dismisses result after transcription
- `install.sh` — one-time setup: installs deps, builds whisper.cpp + indicator, downloads model, registers GNOME hotkey

## License

MIT
