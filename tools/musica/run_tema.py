"""Gera assets/sounds/music/runTema.wav:

    python tools/musica/run_tema.py assets/sounds/music/runTema.wav

Trilha da run — aventura com mistério. Ré menor, 116 BPM, 24 compassos em
loop:
- A (8): aventura. Baixo em ostinato de colcheias, bateria cheia, melodia
  em pulso 25%.
- B (8): mistério. A banda recua: baixo em mínimas, bateria só no bumbo e
  chimbal no contratempo, melodia em pulso 50% (oco) com eco.
- A' (8): a aventura volta mais cheia, melodia dobrada uma oitava abaixo e
  chimbal em semicolcheias. Termina no Lá maior, que puxa o Ré menor do
  recomeço.
"""
import sys

from chip import Faixa, envelope, freq, onda4bits, pulso, pulso_vibrato, SR

# ---------------------------------------------------------------- partitura
A4, Bb4, C5, Cs5, D5, E5, F5, G5, A5, Bb5 = 69, 70, 72, 73, 74, 76, 77, 79, 81, 82
Cs6, D6 = 85, 86

MELODIA_A = [
    [(A4, 2), (D5, 2), (E5, 1), (F5, 3)],
    [(E5, 3), (D5, 1), (C5, 2), (E5, 2)],
    [(D5, 2), (F5, 2), (Bb5, 3), (A5, 1)],
    [(G5, 4), (E5, 2), (C5, 2)],
    [(A4, 2), (D5, 2), (E5, 1), (F5, 2), (G5, 1)],
    [(A5, 3), (G5, 1), (E5, 2), (G5, 2)],
    [(F5, 2), (D5, 2), (Bb4, 2), (D5, 2)],
    [(Cs5, 4), (E5, 2), (A5, 2)],
]
MELODIA_B = [
    [(Bb5, 4), (A5, 2), (G5, 2)],
    [(F5, 6), (None, 2)],
    [(G5, 2), (Bb5, 2), (D6, 4)],
    [(Cs6, 4), (None, 2), (E5, 2)],
    [(F5, 3), (G5, 1), (A5, 4)],
    [(G5, 3), (F5, 1), (E5, 4)],
    [(D5, 2), (F5, 2), (Bb5, 2), (A5, 2)],
    [(A5, 6), (None, 2)],
]

# Um acorde por compasso: (raiz MIDI do baixo, intervalos).
MAI, MEN = [0, 4, 7], [0, 3, 7]
Dm, C, Bb, A, Gm, F = (50, MEN), (48, MAI), (46, MAI), (45, MAI), (43, MEN), (41, MAI)
ACORDES_A = [Dm, C, Bb, C, Dm, C, Bb, A]
ACORDES_B = [Gm, Dm, Gm, A, F, C, Bb, A]

PARTES = [  # (melodia, acordes, nome da parte)
    (MELODIA_A, ACORDES_A, 'A'),
    (MELODIA_B, ACORDES_B, 'B'),
    (MELODIA_A, ACORDES_A, "A'"),
]

f = Faixa(bpm=116, compassos=24)
OITAVA = f.colcheia
SEMI = OITAVA / 2

compasso_global = 0
for melodia, acordes, parte in PARTES:
    misterio = parte == 'B'
    cheia = parte == "A'"
    for c, (compasso, (raiz, ints)) in enumerate(zip(melodia, acordes)):
        assert sum(d for _, d in compasso) == 8, compasso
        base = compasso_global * 8 * OITAVA

        # --- melodia
        t0 = base
        for nota, dur in compasso:
            n = f.amostras(dur)
            if nota is not None:
                duty = 0.5 if misterio else 0.25
                onda = pulso_vibrato(freq(nota), n, duty) if dur >= 3 else pulso(freq(nota), n, duty)
                f.por('eco_fonte' if misterio else 'lead', t0, onda * envelope(n, solta=0.02))
                if cheia:
                    # Dobra uma oitava abaixo, mais baixinha: engorda a volta.
                    f.por('dobra', t0, pulso(freq(nota - 12), n, 0.125) * envelope(n, solta=0.02))
            t0 += dur * OITAVA

        # --- arpejo: semicolcheias na aventura, colcheias no mistério
        tons = [raiz + 12 + k for k in ints] + [raiz + 24]
        passo = OITAVA if misterio else SEMI
        for s in range(int(8 * OITAVA / passo)):
            n = int(round(passo * SR))
            f.por('arpejo', base + s * passo,
                  pulso(freq(tons[s % len(tons)]), n, 0.125)
                  * envelope(n, decai=0.05 if not misterio else 0.12, sustenta=0.3))

        # --- baixo
        if misterio:
            for s, nota in ((0, raiz), (4, raiz + 7)):
                n = f.amostras(4)
                f.por('baixo', base + s * OITAVA,
                      onda4bits(freq(nota), n) * envelope(n, decai=0.4, sustenta=0.5, solta=0.05))
        else:
            for s, nota in enumerate([raiz, raiz, raiz + 12, raiz, raiz + 7, raiz, raiz + 12, raiz]):
                n = int(round(OITAVA * 0.7 * SR))
                f.por('baixo', base + s * OITAVA,
                      onda4bits(freq(nota), n) * envelope(n, decai=0.1, sustenta=0.5))

        # --- bateria
        for s in range(8):
            quando = base + s * OITAVA
            if misterio:
                if s == 0:
                    f.por('bateria', quando, f.bumbo() * 0.8)
                if s % 2 == 1:
                    f.por('bateria', quando, f.chimbal() * 0.8)
                continue
            f.por('bateria', quando, f.chimbal(forte=s % 2 == 0))
            if cheia:
                f.por('bateria', quando + SEMI, f.chimbal() * 0.6)
            if s in (0, 3, 4):
                f.por('bateria', quando, f.bumbo())
            if s in (2, 6):
                f.por('bateria', quando, f.caixa())
        # Virada no fim das partes de aventura, puxando a próxima.
        if not misterio and c == 7:
            for k in range(4):
                f.por('bateria', base + 6 * OITAVA + k * SEMI, f.caixa() * (0.6 + 0.1 * k))

        compasso_global += 1

# Eco do mistério: duas repetições, a 3 semicolcheias uma da outra.
fonte = f.canal('eco_fonte')
atraso = int(round(3 * SEMI * SR))
eco = fonte.copy()
eco[atraso:] += 0.35 * fonte[:-atraso]
eco[2 * atraso:] += 0.15 * fonte[:-2 * atraso]
f.canais['eco'] = eco

f.salvar(sys.argv[1], {
    'lead': 0.22,
    'eco': 0.20,
    'dobra': 0.07,
    'arpejo': 0.07,
    'baixo': 0.26,
    'bateria': 0.15,
})
