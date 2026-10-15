"""Gera assets/sounds/music/gameoverTema.wav:

    python tools/musica/gameover_tema.py assets/sounds/music/gameoverTema.wav

Tema de game over — lamento curto. Lá menor, 76 BPM, 8 compassos em loop,
sem bateria: toca durante a cena de morte e fica de fundo na tela de
resumo, então precisa aguentar repetição sem cansar.

Melodia em pulso 50% (oco, suave) com eco, arpejo lento em colcheias e
baixo em semibreves. Termina em Mi maior, a dominante, que volta pro Lá
menor do começo.
"""
import sys

from chip import Faixa, envelope, freq, onda4bits, pulso, pulso_vibrato, SR

# ---------------------------------------------------------------- partitura
Gs4, A4, B4, C5, D5, E5, F5, G5 = 68, 69, 71, 72, 74, 76, 77, 79
MELODIA = [
    [(E5, 3), (D5, 1), (C5, 2), (B4, 2)],
    [(A4, 4), (C5, 2), (F5, 2)],
    [(E5, 3), (D5, 1), (E5, 2), (G5, 2)],
    [(D5, 6), (None, 2)],
    [(C5, 3), (B4, 1), (A4, 2), (C5, 2)],
    [(F5, 3), (E5, 1), (D5, 2), (A4, 2)],
    [(Gs4, 2), (B4, 2), (E5, 4)],
    [(D5, 3), (C5, 1), (B4, 4)],
]

MAI, MEN = [0, 4, 7], [0, 3, 7]
Am, F, C, G, Dm, E = (45, MEN), (41, MAI), (48, MAI), (43, MAI), (50, MEN), (40, MAI)
ACORDES = [Am, F, C, G, Am, Dm, E, E]

f = Faixa(bpm=76, compassos=8)
OITAVA = f.colcheia

for c, (compasso, (raiz, ints)) in enumerate(zip(MELODIA, ACORDES)):
    assert sum(d for _, d in compasso) == 8, compasso
    base = c * 8 * OITAVA

    # --- melodia
    t0 = base
    for nota, dur in compasso:
        n = f.amostras(dur)
        if nota is not None:
            onda = (pulso_vibrato(freq(nota), n, 0.5, inicio=0.3)
                    if dur >= 3 else pulso(freq(nota), n, 0.5))
            # Ataque mais lento e queda longa: nada de nota martelada aqui.
            f.por('lead', t0, onda * envelope(n, ataque=0.02, decai=0.6, sustenta=0.5, solta=0.08))
        t0 += dur * OITAVA

    # --- arpejo lento em colcheias
    tons = [raiz + 12 + k for k in ints] + [raiz + 24]
    for s in range(8):
        n = f.amostras(1)
        f.por('arpejo', base + s * OITAVA,
              pulso(freq(tons[s % len(tons)]), n, 0.125)
              * envelope(n, decai=0.2, sustenta=0.2, solta=0.03))

    # --- baixo em semibreve
    n = f.amostras(8)
    f.por('baixo', base,
          onda4bits(freq(raiz), n) * envelope(n, ataque=0.02, decai=1.2, sustenta=0.4, solta=0.1))

# Eco da melodia: duas repetições a uma colcheia pontuada.
fonte = f.canal('lead')
atraso = int(round(1.5 * OITAVA * SR))
eco = fonte.copy()
eco[atraso:] += 0.3 * fonte[:-atraso]
eco[2 * atraso:] += 0.12 * fonte[:-2 * atraso]
f.canais['lead'] = eco

f.salvar(sys.argv[1], {'lead': 0.26, 'arpejo': 0.08, 'baixo': 0.26}, fade_fim=0.03)
