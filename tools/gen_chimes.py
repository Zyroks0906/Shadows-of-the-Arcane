"""Crystal chimes for the Echo Grotto puzzle: four bell tones on a pentatonic scale plus a
dissonant cluster for a wrong note. Inharmonic partials with exponential decay give the
glassy bell colour. Writes assets/audio/sfx/puzzle/*.wav (22050 Hz, 16-bit mono)."""
import math, os, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'sfx', 'puzzle')
PARTIALS = [(1.0, 1.0, 1.6), (2.0, 0.45, 2.4), (2.76, 0.3, 3.5), (5.4, 0.12, 6.0), (8.93, 0.05, 9.0)]

def bell(freqs, length=1.6, gain=0.5):
    n = int(RATE * length)
    out = []
    for i in range(n):
        t = i / RATE
        attack = min(t / 0.004, 1.0)
        v = 0.0
        for f in freqs:
            for ratio, amp, decay in PARTIALS:
                v += amp * math.exp(-decay * t) * math.sin(2 * math.pi * f * ratio * t)
        out.append(v * attack)
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * gain for v in out]

def save(name, samples):
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))

os.makedirs(OUT, exist_ok=True)
for i, f in enumerate([523.25, 659.25, 783.99, 880.0]): # C5 E5 G5 A5
    save('chime_%d.wav' % i, bell([f]))
save('chime_wrong.wav', bell([466.16, 493.88, 554.37], 1.0, 0.45)) # Bb4 B4 C#5 cluster
print('ok')
