"""Gera assets/sounds/music/bossTema.wav:

    python tools/musica/boss_tema.py assets/sounds/music/bossTema.wav

Tema de chefe — tensão e urgência. Mi menor com Fá natural e Ré sustenido
(o ameaçador e o que puxa pra resolução), 164 BPM, 26 compassos em loop:
- Abertura (2): descida cromática em semicolcheias e notas marteladas, com
  rufar de caixa crescendo.
- A (8): o motivo de luta. Baixo galopando em oitavas, bumbo em todos os
  tempos.
- B (8): a tensão sobe — notas longas cada vez mais agudas, tímpano nas
  trocas de acorde, bumbo sincopado e chimbal em semicolcheias.
- A' (8): o motivo volta dobrado uma oitava abaixo e com a bateria mais
  cheia. Termina em Si maior, a dominante, que puxa o Mi da abertura.
"""
import sys

from chip import Faixa, envelope, freq, onda4bits, pulso, pulso_vibrato, SR

# ---------------------------------------------------------------- partitura
# (nota MIDI ou None, duração em colcheias — 0.5 = semicolcheia). 8 por compasso.
B4, C5, Cs5, D5, Ds5, E5, F5, Fs5, G5, Gs5 = 71, 72, 73, 74, 75, 76, 77, 78, 79, 80
A5, As5, B5, C6, Cs6, D6, Ds6, E6 = 81, 82, 83, 84, 85, 86, 87, 88

ABERTURA = [
    [(n, 0.5) for n in (E6, Ds6, D6, Cs6, C6, B5, As5, A5,
                        Gs5, G5, Fs5, F5, E5, Ds5, D5, Cs5)],
    [(E5, 1), (None, 1), (E5, 1), (None, 1),
     (B4, 0.5), (C5, 0.5), (D5, 0.5), (Ds5, 0.5), (E5, 2)],
]
TEMA_A = [
    [(E5, 1), (E5, 0.5), (E5, 0.5), (G5, 1), (E5, 1), (B5, 2), (A5, 1), (G5, 1)],
    [(Fs5, 1), (G5, 1), (Fs5, 1), (E5, 1), (D5, 2), (E5, 2)],
    [(C5, 1), (E5, 1), (G5, 1), (C6, 3), (B5, 1), (A5, 1)],
    [(B5, 2), (Ds5, 1), (Fs5, 1), (B5, 3), (None, 1)],
    [(E5, 1), (E5, 0.5), (E5, 0.5), (G5, 1), (E5, 1), (B5, 2), (A5, 1), (G5, 1)],
    [(G5, 1), (A5, 1), (B5, 1), (E6, 3), (D6, 1), (B5, 1)],
    [(A5, 1), (F5, 1), (C6, 2), (A5, 1), (F5, 1), (C5, 2)],
    [(B4, 1), (Ds5, 1), (Fs5, 1), (A5, 1), (B5, 2), (Ds6, 2)],
]
TEMA_B = [
    [(A5, 3), (G5, 1), (E5, 2), (C5, 2)],
    [(B4, 3), (C5, 1), (E5, 4)],
    [(A5, 3), (B5, 1), (C6, 2), (E6, 2)],
    [(Ds6, 4), (B5, 4)],
    [(E6, 2), (D6, 1), (C6, 1), (G5, 4)],
    [(Fs5, 2), (A5, 2), (D6, 4)],
    [(Ds6, 3), (Cs6, 1), (B5, 4)],
    [(B4, 0.5), (Ds5, 0.5), (Fs5, 0.5), (A5, 0.5),
     (B5, 0.5), (A5, 0.5), (Fs5, 0.5), (Ds5, 0.5),
     (B4, 1), (None, 1), (B4, 1), (None, 1)],
]

# Um acorde por compasso: (raiz MIDI do baixo, intervalos).
MAI, MEN, D7 = [0, 4, 7], [0, 3, 7], [0, 4, 7, 10]
Em, C, B, F, Am, D, B7 = (40, MEN), (48, MAI), (47, MAI), (41, MAI), (45, MEN), (50, MAI), (47, D7)
ACORDES_ABERTURA = [Em, Em]
ACORDES_A = [Em, Em, C, B, Em, Em, F, B]
ACORDES_B = [Am, Em, Am, B, C, D, B, B7]

PARTES = [
    ('abertura', ABERTURA, ACORDES_ABERTURA),
    ('A', TEMA_A, ACORDES_A),
    ('B', TEMA_B, ACORDES_B),
    ("A'", TEMA_A, ACORDES_A),
]

f = Faixa(bpm=164, compassos=26, semente=11)
OITAVA = f.colcheia
SEMI = OITAVA / 2

compasso_global = 0
for nome, melodia, acordes in PARTES:
    abertura = nome == 'abertura'
    tensao = nome == 'B'
    cheia = nome == "A'"
    for c, (compasso, (raiz, ints)) in enumerate(zip(melodia, acordes)):
        assert abs(sum(d for _, d in compasso) - 8) < 1e-9, compasso
        base = compasso_global * 8 * OITAVA

        # --- melodia
        t0 = base
        for nota, dur in compasso:
            n = f.amostras(dur)
            if nota is not None:
                onda = pulso_vibrato(freq(nota), n, 0.25) if dur >= 3 else pulso(freq(nota), n, 0.25)
                # Notas curtas bem destacadas: é o que dá a urgência.
                env = envelope(n, decai=0.08 if dur < 1 else 0.15, solta=0.015)
                f.por('lead', t0, onda * env)
                if cheia:
                    f.por('dobra', t0, pulso(freq(nota - 12), n, 0.125) * env)
            t0 += dur * OITAVA

        # --- arpejo em semicolcheias, sobe e desce pelo acorde
        if not abertura:
            tons = [raiz + 12 + k for k in ints] + [raiz + 24]
            vaivem = tons + tons[-2:0:-1]
            for s in range(16):
                n = int(round(SEMI * SR))
                f.por('arpejo', base + s * SEMI,
                      pulso(freq(vaivem[s % len(vaivem)]), n, 0.125)
                      * envelope(n, decai=0.04, sustenta=0.25))

        # --- baixo galopando: raiz e oitava em semicolcheias
        for s in range(16):
            nota = raiz if s % 2 == 0 else raiz + 12
            n = int(round(SEMI * 0.6 * SR))
            f.por('baixo', base + s * SEMI,
                  onda4bits(freq(nota), n) * envelope(n, decai=0.06, sustenta=0.5))

        # --- percussão
        if abertura:
            for s in range(16):
                forca = 0.3 + 0.7 * ((c * 16 + s) / 31)
                f.por('bateria', base + s * SEMI, f.caixa() * forca)
            if c == 0:
                f.por('bateria', base, f.timpano(raiz, 0.5))
        else:
            if c == 0:
                f.por('bateria', base, f.prato() * 0.7)
            if tensao:
                f.por('bateria', base, f.timpano(raiz) * 0.9)
            for s in range(8):
                quando = base + s * OITAVA
                if tensao:
                    if s in (0, 3, 6):
                        f.por('bateria', quando, f.bumbo())
                    f.por('bateria', quando, f.chimbal(forte=True))
                    f.por('bateria', quando + SEMI, f.chimbal())
                else:
                    if s % 2 == 0:
                        f.por('bateria', quando, f.bumbo())
                    f.por('bateria', quando, f.chimbal(forte=s % 2 == 0))
                    if cheia:
                        f.por('bateria', quando + SEMI, f.chimbal() * 0.6)
                if s in (2, 6):
                    f.por('bateria', quando, f.caixa())
            # Virada no fim de cada parte.
            if c == len(melodia) - 1:
                for k in range(4):
                    f.por('bateria', base + 6 * OITAVA + k * SEMI, f.caixa() * (0.6 + 0.1 * k))

        compasso_global += 1

f.salvar(sys.argv[1], {
    'lead': 0.22,
    'dobra': 0.07,
    'arpejo': 0.06,
    'baixo': 0.24,
    'bateria': 0.17,
})
