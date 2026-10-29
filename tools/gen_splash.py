"""Footstep splashes for shallow water: a short filtered-noise slosh with a couple of
bubbly blips, three variants so steps don't repeat. Writes assets/audio/sfx/water/*.wav."""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'sfx', 'water')

def splash(seed):
    rnd = random.Random(seed)
    n = int(RATE * 0.32)
    out, lp, lp2 = [], 0.0, 0.0
    blips = [(rnd.uniform(0.03, 0.12), rnd.uniform(500, 900), rnd.uniform(0.04, 0.07)) for _ in range(3)]
    for i in range(n):
        t = i / RATE
        env = min(t / 0.008, 1.0) * math.exp(-t * rnd.uniform(14, 18))
        noise = rnd.uniform(-1, 1)
        lp += (noise - lp) * 0.22          # low-pass: a wet hiss, not static
        lp2 += (lp - lp2) * 0.35
        v = (lp - lp2 * 0.6) * env * 1.6
        for start, f, dur in blips:      # small rising bubbles
            if start <= t < start + dur:
                k = (t - start) / dur
                v += 0.35 * math.sin(2 * math.pi * f * (1 + k * 0.8) * (t - start)) * math.sin(math.pi * k)
        out.append(v)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.6 for v in out]

os.makedirs(OUT, exist_ok=True)
for i in range(3):
    with wave.open(os.path.join(OUT, 'splash_%d.wav' % i), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(s * 32767)) for s in splash(i * 7 + 3)))
print('ok')
