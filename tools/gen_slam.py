"""A ground slam: a deep falling thump (the body of the blow), a short crunch of broken
stone on top, and a low rumble that rolls off. Writes assets/audio/sfx/impact/slam.wav."""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'sfx', 'impact')
rnd = random.Random(5)
n = int(RATE * 1.1)
out = []
lp = lp2 = rum = 0.0
phase = 0.0
for i in range(n):
    t = i / RATE
    # Thump: a sine falling from 90 Hz to 38 Hz, fast attack, quick decay.
    f = 38 + 52 * math.exp(-t * 9)
    phase += 2 * math.pi * f / RATE
    thump = math.sin(phase) * math.exp(-t * 6.5) * min(t / 0.003, 1.0)
    # Crunch: low-passed noise burst in the first 120 ms (stone breaking).
    noise = rnd.uniform(-1, 1)
    lp += (noise - lp) * 0.3
    crunch = lp * math.exp(-t * 26) * 0.9
    # Rumble: very low-passed noise tail.
    lp2 += (noise - lp2) * 0.02
    rum += (lp2 - rum) * 0.05
    rumble = rum * 6.0 * math.exp(-t * 3.0) * min(t / 0.05, 1.0)
    out.append(thump * 1.0 + crunch + rumble)
peak = max(abs(v) for v in out) or 1.0
os.makedirs(OUT, exist_ok=True)
with wave.open(os.path.join(OUT, 'slam.wav'), 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', int(v / peak * 0.85 * 32767)) for v in out))
print('ok')
