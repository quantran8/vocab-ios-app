"""Sound effects for the end-of-session celebration (`CelebrateV2`, `SessionCelebrationView`).

Generates each sound with the ElevenLabs sound-generation API, converts it to the app's format
(16-bit 44.1 kHz mono WAV) into `VocabFlow/Resources/Sounds/<name>.wav`, then rebuilds the
per-variant previews in `preview/` with the cue times of `CelebrationVariant.soundCues`.

    ELEVENLABS_API_KEY=... python3 design/sounds/celebration/generate.py            # all sounds
    ELEVENLABS_API_KEY=... python3 design/sounds/celebration/generate.py flip_land  # one sound (name without "celebrate_")
    python3 design/sounds/celebration/generate.py --preview                        # previews only, no API call

The key needs the "Sound Effects" permission. ElevenLabs output varies per call, so regenerating
gives a different take; listen to the preview before keeping it. Uses curl (the system Python on
this Mac lacks SSL certificates) and macOS afconvert.
"""
import array
import json
import os
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOUNDS_DIR = os.path.join(ROOT, "VocabFlow", "Resources", "Sounds")
PREVIEW_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview")
URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

# name: (prompt, duration in seconds, gain in dB applied after conversion to even out loudness)
SOUNDS = {
    "puff_inhale": ("Cute cartoon character taking a big deep inhale, puffing up like a balloon, rising pitch, playful", 0.8, 0),
    "puff_pop": ("Cartoon balloon pop followed by a party popper confetti burst, bright and cheerful", 1.0, 0),
    "puff_land": ("Soft cute cartoon landing bump with a small sparkle chime", 0.8, 0),
    "fireworks_rise": ("Magical whoosh rising upward with small firework crackles and pops in the background, playful and light", 2.0, -3),
    "fireworks_finale": ("Big firework explosion boom followed by glittering sparkling crackle shimmer slowly fading out, celebratory", 2.5, 0),
    "flip_jump": ("Cartoon spring jump boing with a quick upward whoosh", 0.7, -3),
    "flip_spin": ("Fast airy double spin whoosh, two quick swooshes, light and playful", 1.1, -3),
    "flip_land": ("Soft cartoon landing thump followed by a bright magical sparkle chime", 1.2, 0),
    "loop_swoosh": ("Two playful looping whooshes with a twinkling sparkle trail, magical and light", 1.6, 0),
    "loop_sparkle": ("Magical sparkle burst chime, glittering twinkles, celebratory and bright", 1.2, 7),
    "bounce_boing": ("Short cute cartoon boing bounce, rubbery and playful", 0.5, -4),
    "bounce_launch": ("Big cartoon spring launch boing with a rising whoosh", 0.8, 0),
    "bounce_land": ("Cartoon landing thud followed by a party popper confetti burst, cheerful", 1.2, 0),
}

# Mirrors CelebrationVariant.soundCues in SessionCelebrationView.swift (seconds from the start of the animation).
CUES = {
    "puff": [("puff_inhale", 0.30), ("puff_pop", 0.95), ("puff_land", 1.95)],
    "fireworks": [("fireworks_rise", 0.0), ("fireworks_finale", 2.08)],
    "flip": [("flip_jump", 0.60), ("flip_spin", 0.85), ("flip_land", 2.15)],
    "loop": [("loop_swoosh", 0.35), ("loop_sparkle", 2.45)],
    "bounce": [("bounce_boing", 0.78), ("bounce_boing", 1.38), ("bounce_launch", 1.55), ("bounce_land", 2.48)],
}

RATE = 44100


def wav_path(name):
    return os.path.join(SOUNDS_DIR, f"celebrate_{name}.wav")


def read_samples(path):
    with wave.open(path) as w:
        return w.getparams(), array.array("h", w.readframes(w.getnframes()))


def write_samples(path, params, samples):
    with wave.open(path, "wb") as w:
        w.setparams(params)
        w.writeframes(samples.tobytes())


def clip(x):
    return max(-32767, min(32767, int(x)))


def generate(name, key):
    prompt, duration, gain = SOUNDS[name]
    body = json.dumps({"text": prompt, "duration_seconds": duration, "prompt_influence": 0.5})
    with tempfile.TemporaryDirectory() as tmp:
        mp3 = os.path.join(tmp, "sound.mp3")
        status = subprocess.run(
            ["curl", "-s", "-o", mp3, "-w", "%{http_code}", "-X", "POST", URL,
             "-H", f"xi-api-key: {key}", "-H", "Content-Type: application/json", "-d", body],
            check=True, capture_output=True, text=True,
        ).stdout
        if status != "200":
            with open(mp3, "rb") as f:
                raise SystemExit(f"{name}: HTTP {status} {f.read()[:300]!r}")
        out = wav_path(name)
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "1", mp3, out], check=True)
    if gain:
        params, samples = read_samples(out)
        factor = 10 ** (gain / 20)
        write_samples(out, params, array.array("h", (clip(x * factor) for x in samples)))
    print(f"celebrate_{name}.wav")


def build_previews():
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for variant, cues in CUES.items():
        mix = [0] * (RATE * 5)
        for name, at in cues:
            _, samples = read_samples(wav_path(name))
            start = int(at * RATE)
            for i, x in enumerate(samples[: len(mix) - start]):
                mix[start + i] += x
        with wave.open(os.path.join(PREVIEW_DIR, f"{variant}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(array.array("h", (clip(x) for x in mix)).tobytes())
        print(f"preview/{variant}.wav")


def main():
    args = sys.argv[1:]
    if args != ["--preview"]:
        key = os.environ.get("ELEVENLABS_API_KEY")
        if not key:
            raise SystemExit("Set ELEVENLABS_API_KEY (needs the Sound Effects permission).")
        for name in args or SOUNDS:
            generate(name, key)
    build_previews()


if __name__ == "__main__":
    main()
