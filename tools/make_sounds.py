#!/usr/bin/env python3
"""Synthesises every sound in addons/natural_disasters/audio/ from fixed seeds.

Filtered noise and enveloped impulses only: no recordings and no third-party samples, so the
files are this repository's own and are dedicated to the public domain under CC0 1.0 with the
rest of the addon's assets. Loops are shaped in the frequency domain, which makes them
periodic by construction, so they have no seam to hide.

    python3 tools/make_sounds.py        # needs numpy and ffmpeg
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "addons", "natural_disasters", "audio")


def shaped_noise(rng, seconds, shape):
    """Periodic noise whose magnitude spectrum is shape(freq_hz)."""
    n = int(RATE * seconds)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    spec = (rng.normal(size=freqs.size) + 1j * rng.normal(size=freqs.size)) * shape(freqs)
    spec[0] = 0
    return np.fft.irfft(spec, n)


def loop_mod(n, cycles, depth, phase=0.0):
    """A slow amplitude modulation with a whole number of cycles, so the loop is seamless."""
    t = np.arange(n) / n
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t + phase))


def band(lo, hi, slope=0.0):
    def f(x):
        x = np.maximum(x, 1.0)
        edge = np.clip((x - lo) / (lo * 0.5), 0, 1) * np.clip((hi - x) / (hi * 0.5), 0, 1)
        return edge * (x / 1000.0) ** slope
    return f


def normalise(x, peak=0.8):
    return x / max(np.max(np.abs(x)), 1e-9) * peak


def wind(rng):
    s = 12
    base = shaped_noise(rng, s, band(80, 1400, -0.8))
    whistle = shaped_noise(rng, s, band(500, 1100, 0.0))
    n = base.size
    return normalise(base * loop_mod(n, 3, 0.55) + 0.35 * whistle * loop_mod(n, 5, 0.9, 1.0))


def rain(rng):
    s = 10
    hiss = shaped_noise(rng, s, band(1500, 12000, -0.3))
    n = hiss.size
    drops = np.zeros(n)
    idx = rng.integers(0, n, size=int(s * 380))
    drops[idx] = rng.uniform(0.2, 1.0, size=idx.size)
    kernel = np.exp(-np.arange(240) / 28.0) * np.sin(np.arange(240) * 0.9)
    drops = np.real(np.fft.ifft(np.fft.fft(drops) * np.fft.fft(kernel, n)))
    return normalise(hiss * loop_mod(n, 2, 0.2) + 0.5 * normalise(drops))


def tornado(rng):
    s = 10
    low = shaped_noise(rng, s, band(30, 260, -0.2))
    mid = shaped_noise(rng, s, band(200, 1800, -1.0))
    n = low.size
    return normalise(low * loop_mod(n, 4, 0.5) + 0.5 * mid * loop_mod(n, 7, 0.7, 2.0))


def quake(rng):
    s = 8
    sub = shaped_noise(rng, s, band(18, 140, -0.1))
    n = sub.size
    crack = np.zeros(n)
    idx = rng.integers(0, n, size=int(s * 9))
    crack[idx] = rng.uniform(0.3, 1.0, size=idx.size)
    kernel = np.exp(-np.arange(2400) / 500.0) * rng.normal(size=2400)
    crack = np.real(np.fft.ifft(np.fft.fft(crack) * np.fft.fft(kernel, n)))
    return normalise(sub * loop_mod(n, 11, 0.45) + 0.4 * normalise(crack))


def thunder(rng, seconds):
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    rumble = shaped_noise(rng, seconds, band(25, 220, -0.3))
    env = np.zeros(n)
    for start, amp in [(0.15, 1.0)] + [(rng.uniform(0.6, seconds * 0.6), rng.uniform(0.3, 0.8)) for _ in range(3)]:
        env += amp * np.where(t >= start, np.exp(-(t - start) / rng.uniform(0.7, 1.4)), 0.0)
    crack = shaped_noise(rng, seconds, band(300, 6000, 0.0)) * np.where(t >= 0.1, np.exp(-(t - 0.1) / 0.07), 0.0)
    out = rumble * env + 1.6 * crack * np.exp(-t * 0.0)
    fade = np.clip((seconds - t) / 0.6, 0, 1)
    return normalise(out * fade)


def write(name, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        os.makedirs(OUT, exist_ok=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3",
                        os.path.join(OUT, name + ".ogg")], check=True)


def main():
    write("wind_loop", wind(np.random.default_rng(101)))
    write("rain_loop", rain(np.random.default_rng(102)))
    write("tornado_loop", tornado(np.random.default_rng(103)))
    write("quake_rumble", quake(np.random.default_rng(104)))
    for i, seconds in enumerate([4.5, 5.5, 3.8], start=1):
        write("thunder_%d" % i, thunder(np.random.default_rng(200 + i), seconds))


if __name__ == "__main__":
    main()
