# whisper-dictate

Offline voice dictation for Linux (GNOME/Wayland). Press a hotkey to start recording, press again to transcribe — text is copied to your clipboard instantly.

Built on [whisper.cpp](https://github.com/ggml-org/whisper.cpp). No cloud, no subscription, no internet required after setup.

## Requirements

- Ubuntu/Debian-based Linux
- GNOME desktop (Wayland)
- Microphone

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
| Press hotkey | 🎙 Listening... |
| Press hotkey again | Transcribes → copies to clipboard |
| `Ctrl+V` | Paste anywhere |

A notification shows the transcribed text so you can review before pasting.

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

- `toggle.sh` — the hotkey script. Records audio via `arecord`, transcribes with `whisper-cli`, copies result with `wl-copy`
- `install.sh` — one-time setup: installs deps, builds whisper.cpp, downloads model, registers GNOME hotkey

## License

MIT
