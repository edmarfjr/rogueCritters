"""Gera assets/sounds/music/menuTema.wav:

    python tools/musica/menu_tema.py assets/sounds/music/menuTema.wav

Tema do menu principal — marcha heroica que anuncia a aventura. 128 BPM,
26 compassos em loop:
- Fanfarra (2): chamada de trombeta em Ré com rufar de tímpanos.
- A (8) e B (8): o tema em Sol maior, melodia em pulso 50% com uma segunda
  voz em terças abaixo, tímpano na cabeça de cada compasso.
- A modulado (8): o tema de novo um tom acima, em Lá maior, com prato de
  ataque — o "agora é pra valer". Termina em Lá, a dominante de Ré, e por
  isso emenda direto na fanfarra do recomeço.
"""
import sys

from chip import Faixa, envelope, freq, onda4bits, pulso, pulso_vibrato, SR

# ---------------------------------------------------------------- partitura
# Melodia: (nota MIDI ou None pra pausa, duração em colcheias). 8 por compasso.
D5, E5, Fs5, G5, A5, B5, C6 = 74, 76, 78, 79, 81, 83, 84
G4, A4, B4, C5 = 67, 69, 71, 72
FANFARRA = [
    [(A4, 1), (D5, 1), (Fs5, 1), (A5, 5)],
    [(G5, 1), (Fs5, 1), (E5, 1), (Fs5, 3), (A4, 2)],
]
TEMA_A = [
    [(D5, 2), (B4, 1), (D5, 1), (G5, 3), (Fs5, 1)],
    [(E5, 2), (D5, 1), (B4, 1), (G4, 2), (B4, 2)],
    [(C5, 2), (E5, 1), (G5, 1), (E5, 2), (C5, 1), (E5, 1)],
    [(D5, 3), (Fs5, 1), (A5, 4)],
    [(G5, 2), (Fs5, 1), (E5, 1), (D5, 2), (B4, 2)],
    [(E5, 1), (Fs5, 1), (G5, 2), (B5, 3), (A5, 1)],
    [(G5, 2), (E5, 2), (Fs5, 2), (A5, 2)],
    [(G5, 6), (None, 2)],
]
TEMA_B = [
    [(E5, 2), (G5, 1), (E5, 1), (C5, 2), (E5, 2)],
    [(Fs5, 2), (A5, 1), (Fs5, 1), (D5, 2), (Fs5, 2)],
    [(Fs5, 3), (D5, 1), (B4, 2), (D5, 2)],
    [(E5, 3), (G5, 1), (B5, 2), (G5, 2)],
    [(C6, 3), (B5, 1), (A5, 2), (G5, 2)],
    [(Fs5, 2), (G5, 1), (A5, 1), (D5, 4)],
    [(E5, 2), (G5, 2), (Fs5, 2), (E5, 1), (Fs5, 1)],
    [(D5, 4), (None, 2), (D5, 1), (Fs5, 1)],
]

# Acordes por meio compasso: (raiz MIDI do baixo, intervalos).
MAI, MEN, M7, D7 = [0, 4, 7], [0, 3, 7], [0, 3, 7, 10], [0, 4, 7, 10]
G, Em, C, D, Bm, Am7, D7c = (43, MAI), (40, MEN), (48, MAI), (38, MAI), (47, MEN), (45, M7), (38, D7)
ACORDES_FANFARRA = [D, D, D, D7c]
ACORDES_A = [G, G, Em, Em, C, C, D, D, G, G, Em, Em, C, D, G, G]
ACORDES_B = [C, C, D, D, Bm, Bm, Em, Em, C, C, D, D, Am7, D7c, D7c, D7c]

# Sol maior em classes de nota, pra achar a terça diatônica abaixo.
ESCALA = [7, 9, 11, 0, 2, 4, 6]


def terca_abaixo(nota):
    """Dois graus abaixo na escala de Sol maior (a segunda voz)."""
    grau = ESCALA.index(nota % 12)
    alvo = ESCALA[(grau - 2) % 7]
    abaixo = nota - ((nota - alvo) % 12)
    return abaixo if abaixo < nota else abaixo - 12


def transpor(compassos, semitons):
    return [[(None if n is None else n + semitons, d) for n, d in c] for c in compassos]


def transpor_acordes(acordes, semitons):
    return [(r + semitons, i) for r, i in acordes]


# (melodia, acordes por meio compasso, segunda voz?, transposição da voz)
PARTES = [
    ('fanfarra', FANFARRA, ACORDES_FANFARRA, 0),
    ('A', TEMA_A, ACORDES_A, 0),
    ('B', TEMA_B, ACORDES_B, 0),
    ('A+', transpor(TEMA_A, 2), transpor_acordes(ACORDES_A, 2), 2),
]

f = Faixa(bpm=128, compassos=26)
OITAVA = f.colcheia
SEMI = OITAVA / 2

compasso_global = 0
for nome, melodia, acordes, tom in PARTES:
    fanfarra = nome == 'fanfarra'
    for c, compasso in enumerate(melodia):
        assert sum(d for _, d in compasso) == 8, compasso
        base = compasso_global * 8 * OITAVA

        # --- melodia (pulso 50%, mais cheio) e a segunda voz em terças
        t0 = base
        for nota, dur in compasso:
            n = f.amostras(dur)
            if nota is not None:
                onda = pulso_vibrato(freq(nota), n, 0.5) if dur >= 3 else pulso(freq(nota), n, 0.5)
                f.por('lead', t0, onda * envelope(n, solta=0.02))
                if not fanfarra:
                    voz = terca_abaixo(nota - tom) + tom
                    f.por('voz', t0, pulso(freq(voz), n, 0.25) * envelope(n, solta=0.02))
            t0 += dur * OITAVA

        for meio in range(2):
            raiz, ints = acordes[c * 2 + meio]
            inicio = base + meio * 4 * OITAVA

            # --- arpejo, só fora da fanfarra (lá a chamada fica sozinha)
            if not fanfarra:
                tons = [raiz + 12 + k for k in ints] + [raiz + 24]
                for s in range(8):
                    n = int(round(SEMI * SR))
                    f.por('arpejo', inicio + s * SEMI,
                          pulso(freq(tons[s % len(tons)]), n, 0.125)
                          * envelope(n, decai=0.05, sustenta=0.3))

            # --- baixo: na fanfarra, nota longa; no tema, "boom-chuck"
            if fanfarra:
                n = f.amostras(4)
                f.por('baixo', inicio,
                      onda4bits(freq(raiz), n) * envelope(n, decai=0.5, sustenta=0.6, solta=0.05))
            else:
                for s, nota in enumerate([raiz, raiz + 12, raiz + 7, raiz + 12]):
                    n = int(round(OITAVA * 0.85 * SR))
                    f.por('baixo', inicio + s * OITAVA,
                          onda4bits(freq(nota), n) * envelope(n, decai=0.12, sustenta=0.6))

        # --- percussão
        raiz_compasso = acordes[c * 2][0]
        if fanfarra:
            # Rufar de tímpano crescendo pela fanfarra inteira.
            for s in range(16):
                forca = 0.35 + 0.65 * ((c * 16 + s) / 31)
                f.por('bateria', base + s * SEMI, f.timpano(raiz_compasso, 0.18) * forca)
        else:
            f.por('bateria', base, f.timpano(raiz_compasso) * 0.9)
            for s in range(8):
                quando = base + s * OITAVA
                f.por('bateria', quando, f.chimbal(forte=s % 2 == 0))
                if s in (0, 4) or (s == 7 and c % 4 == 3):
                    f.por('bateria', quando, f.bumbo())
                if s in (2, 6):
                    f.por('bateria', quando, f.caixa())
            # Virada de caixa no fim de cada parte, puxando a próxima.
            if c == len(melodia) - 1:
                for k in range(4):
                    f.por('bateria', base + 6 * OITAVA + k * SEMI, f.caixa() * (0.6 + 0.1 * k))
        # Prato na entrada do tema e da modulação.
        if c == 0 and nome in ('A', 'A+'):
            f.por('bateria', base, f.prato() * 0.7)

        compasso_global += 1

f.salvar(sys.argv[1], {
    'lead': 0.20,
    'voz': 0.09,
    'arpejo': 0.06,
    'baixo': 0.26,
    'bateria': 0.17,
})
