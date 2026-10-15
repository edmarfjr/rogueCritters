"""Gera assets/sounds/music/vitoriaTema.wav:

    python tools/musica/vitoria_tema.py assets/sounds/music/vitoriaTema.wav

Tema de vitória — fanfarra triunfal pra tela de fim de jogo. Dó maior,
132 BPM, 8 compassos em loop. Abre com a chamada "ta-ta-ta TAAA", melodia em
pulso 50% com segunda voz em terças, baixo "boom-chuck", tímpano em cada
compasso e prato na abertura. Termina na tônica, então o loop recomeça
anunciando a vitória de novo.
"""
import sys

from chip import Faixa, envelope, freq, onda4bits, pulso, pulso_vibrato, SR

E5, F5, G5, A5, B5, C6, D6, F6 = 76, 77, 79, 81, 83, 84, 86, 89
D5 = 74
MELODIA = [
    [(G5, 1), (G5, 1), (G5, 1), (C6, 5)],
    [(A5, 2), (G5, 2), (F5, 2), (E5, 2)],
    [(D5, 2), (G5, 2), (B5, 3), (A5, 1)],
    [(G5, 6), (None, 2)],
    [(E5, 2), (A5, 2), (C6, 3), (B5, 1)],
    [(A5, 2), (F5, 2), (C6, 4)],
    [(B5, 2), (D6, 2), (F6, 2), (D6, 2)],
    [(C6, 6), (None, 2)],
]

MAI, MEN, D7 = [0, 4, 7], [0, 3, 7], [0, 4, 7, 10]
C, F, G, Am, G7 = (48, MAI), (41, MAI), (43, MAI), (45, MEN), (43, D7)
# Por meio compasso.
ACORDES = [C, C, F, C, G, G, C, C, Am, Am, F, F, G, G7, C, C]

# Dó maior em classes de nota, pra segunda voz em terças.
ESCALA = [0, 2, 4, 5, 7, 9, 11]


def terca_abaixo(nota):
    grau = ESCALA.index(nota % 12)
    alvo = ESCALA[(grau - 2) % 7]
    abaixo = nota - ((nota - alvo) % 12)
    return abaixo if abaixo < nota else abaixo - 12


f = Faixa(bpm=132, compassos=8, semente=5)
OITAVA = f.colcheia
SEMI = OITAVA / 2

for c, compasso in enumerate(MELODIA):
    assert sum(d for _, d in compasso) == 8, compasso
    base = c * 8 * OITAVA

    t0 = base
    for nota, dur in compasso:
        n = f.amostras(dur)
        if nota is not None:
            onda = pulso_vibrato(freq(nota), n, 0.5) if dur >= 3 else pulso(freq(nota), n, 0.5)
            f.por('lead', t0, onda * envelope(n, solta=0.02))
            f.por('voz', t0, pulso(freq(terca_abaixo(nota)), n, 0.25) * envelope(n, solta=0.02))
        t0 += dur * OITAVA

    for meio in range(2):
        raiz, ints = ACORDES[c * 2 + meio]
        inicio = base + meio * 4 * OITAVA
        tons = [raiz + 12 + k for k in ints] + [raiz + 24]
        for s in range(8):
            n = int(round(SEMI * SR))
            f.por('arpejo', inicio + s * SEMI,
                  pulso(freq(tons[s % len(tons)]), n, 0.125) * envelope(n, decai=0.05, sustenta=0.3))
        for s, nota in enumerate([raiz, raiz + 12, raiz + 7, raiz + 12]):
            n = int(round(OITAVA * 0.85 * SR))
            f.por('baixo', inicio + s * OITAVA,
                  onda4bits(freq(nota), n) * envelope(n, decai=0.12, sustenta=0.6))

    f.por('bateria', base, f.timpano(ACORDES[c * 2][0]) * 0.9)
    for s in range(8):
        quando = base + s * OITAVA
        f.por('bateria', quando, f.chimbal(forte=s % 2 == 0))
        if s in (0, 4):
            f.por('bateria', quando, f.bumbo())
        if s in (2, 6):
            f.por('bateria', quando, f.caixa())
    if c == 0:
        f.por('bateria', base, f.prato() * 0.7)
    if c == 7:
        for k in range(4):
            f.por('bateria', base + 6 * OITAVA + k * SEMI, f.caixa() * (0.6 + 0.1 * k))

f.salvar(sys.argv[1], {
    'lead': 0.21,
    'voz': 0.09,
    'arpejo': 0.06,
    'baixo': 0.26,
    'bateria': 0.17,
}, fade_fim=0.02)
