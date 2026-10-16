"""Sintetiza os loops de ambiente do jogo (obra própria, CC0) em assets/audio/ambience/.

Cada loop tem 24 s e fecha sem emenda (o fim é misturado ao começo). Camadas:
vento (ruído filtrado com rajadas), folhas, ondas, pássaros, sapos, bolhas, fogo,
gotas de caverna e um zumbido grave para as regiões corrompidas.

Uso: python tools/synth_ambience.py   (precisa de numpy, soundfile e lameenc)
"""
import os
import numpy as np
import lameenc

SR = 44100
DUR = 24.0
N = int(SR * DUR)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")
rng = np.random.default_rng(20261016)
t = np.arange(N) / SR


def lowpass(x, cutoff):
    """Filtro de 1 polo aplicado no domínio da frequência (circular, então o loop fecha)."""
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1.0 / np.sqrt(1.0 + (freqs / hi) ** 4) * (1.0 - 1.0 / np.sqrt(1.0 + (freqs / lo) ** 4))
    return np.fft.irfft(f, len(x))


def slow_env(rate_hz, depth, phase=0.0):
    """Envelope periódico (inteiro de ciclos no loop) para rajadas sem emenda."""
    cycles = max(1, round(rate_hz * DUR))
    e = np.zeros(N)
    for k, amp in [(cycles, 1.0), (cycles * 2 + 1, 0.5), (cycles * 3 + 2, 0.25)]:
        e += amp * np.sin(2 * np.pi * k * t / DUR + phase + k)
    e = e / np.max(np.abs(e))
    return 1.0 - depth + depth * (0.5 + 0.5 * e)


def noise():
    return rng.standard_normal(N)


def wind(strength=1.0, cutoff=500.0, gust=0.6):
    w = lowpass(noise(), cutoff) * slow_env(0.12, gust)
    whistle = bandpass(noise(), cutoff * 1.8, cutoff * 2.2) * slow_env(0.08, 0.9, 1.3) * 0.3
    return (w + whistle) * strength


def leaves():
    return bandpass(noise(), 2500, 7000) * slow_env(0.2, 0.8, 0.7) * 0.25


def waves():
    out = np.zeros(N)
    period = 6.0
    for start in np.arange(0, DUR, period):
        s = start + rng.uniform(-0.4, 0.4)
        env = np.exp(-((t - s - 1.8) % DUR) / 2.2) * (((t - s) % DUR) > 0) * np.clip(((t - s) % DUR) / 1.5, 0, 1)
        out += env
    surf = lowpass(noise(), 1800) * out + lowpass(noise(), 220) * 0.6
    return surf


def chirp(f0, f1, dur, amp):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * tt / dur) ** 2
    return amp * env * np.sin(ph)


def scatter(out, sound, count, jitter=True):
    for _ in range(count):
        p = int(rng.uniform(0, N))
        idx = (np.arange(len(sound)) + p) % N
        out[idx] += sound * (rng.uniform(0.5, 1.0) if jitter else 1.0)
    return out


def birds():
    out = np.zeros(N)
    for _ in range(14):
        base = rng.uniform(2500, 4200)
        song = np.concatenate([chirp(base, base * rng.uniform(1.1, 1.5), rng.uniform(0.06, 0.14), 0.15)
                               for _ in range(rng.integers(2, 6))])
        scatter(out, song, 1)
    return out


def frogs():
    out = np.zeros(N)
    for _ in range(26):
        f = rng.uniform(180, 320)
        n = int(0.18 * SR)
        tt = np.arange(n) / SR
        croak = np.sin(2 * np.pi * f * tt) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * tt))) * np.sin(np.pi * tt / 0.18)
        scatter(out, croak * 0.18, 1)
    return lowpass(out, 1200)


def bubbles():
    out = np.zeros(N)
    for _ in range(60):
        f = rng.uniform(300, 900)
        n = int(0.06 * SR)
        tt = np.arange(n) / SR
        b = np.sin(2 * np.pi * (f + 3000 * tt) * tt) * np.exp(-tt * 60)
        scatter(out, b * 0.25, 1)
    return out


def fire():
    roar = lowpass(noise(), 300) * slow_env(0.4, 0.5) * 0.5
    crackle = np.zeros(N)
    for _ in range(320):
        n = int(rng.uniform(0.002, 0.01) * SR)
        c = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4))
        scatter(crackle, c * rng.uniform(0.2, 0.9), 1)
    return roar + bandpass(crackle, 800, 8000)


def drips():
    out = np.zeros(N)
    for _ in range(18):
        f = rng.uniform(900, 1700)
        n = int(0.25 * SR)
        tt = np.arange(n) / SR
        d = np.sin(2 * np.pi * f * (1 + 0.6 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 18)
        scatter(out, d * 0.3, 1)
    room = lowpass(noise(), 120) * 0.25
    # Eco simples (circular).
    echo = np.roll(out, int(0.23 * SR)) * 0.35 + np.roll(out, int(0.51 * SR)) * 0.15
    return out + echo + room


def drone(f=55.0):
    d = np.zeros(N)
    for k, a in [(1, 1.0), (1.5, 0.4), (2.01, 0.3), (3.0, 0.12)]:
        ff = round(f * k * DUR) / DUR  # frequência com ciclos inteiros
        d += a * np.sin(2 * np.pi * ff * t + rng.uniform(0, 6))
    return d * slow_env(0.05, 0.5) * 0.25 + lowpass(noise(), 90) * 0.4


def normalize(x, peak=0.6):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x, peak=0.6):
    os.makedirs(OUT, exist_ok=True)
    x = normalize(x, peak)
    stereo = np.stack([x, np.roll(x, int(0.013 * SR))], axis=1)  # leve abertura estéreo
    pcm = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    enc = lameenc.Encoder()
    enc.set_bit_rate(128)
    enc.set_in_sample_rate(SR)
    enc.set_channels(2)
    enc.set_quality(2)
    data = enc.encode(pcm.tobytes()) + enc.flush()
    path = os.path.join(OUT, name + ".mp3")
    open(path, "wb").write(data)
    print(path, len(data) // 1024, "KB")


if __name__ == "__main__":
    save("wind_soft", wind(0.6, 420, 0.5) + leaves() * 0.5, 0.45)
    save("forest_day", wind(0.35, 380, 0.4) + leaves() + birds(), 0.5)
    save("wind_peaks", wind(1.0, 650, 0.85), 0.6)
    save("waves", waves(), 0.55)
    save("swamp", drone(49.0) * 0.6 + frogs() + bubbles() * 0.6, 0.5)
    save("burnt", drone(41.0) + fire() * 0.35 + wind(0.4, 300, 0.6), 0.5)
    save("fire", fire(), 0.6)
    save("cave", drips() + drone(36.0) * 0.4, 0.5)
    save("corruption", drone(55.0), 0.4)
