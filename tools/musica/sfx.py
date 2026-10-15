"""Gera os efeitos sonoros em assets/sounds/sfx/:

    python tools/musica/sfx.py assets/sounds/sfx

Mesmo motor das músicas (`chip.py`): pulso, onda e ruído no estilo Game Boy.
Cada função devolve o sinal; `main` normaliza e grava.
"""
import os
import sys
import wave

import numpy as np

from chip import SR, freq, sem_clique

rng = np.random.default_rng(3)


def _t(dur):
    return np.arange(int(dur * SR)) / SR


def _pulso_varrido(f_ini, f_fim, dur, duty, curva=1.0):
    """Pulso com o tom indo de [f_ini] a [f_fim] (exponencial)."""
    t = _t(dur)
    p = (t / dur) ** curva
    f = f_ini * (f_fim / f_ini) ** p
    fase = np.cumsum(f) / SR
    return np.where((fase % 1.0) < duty, 1.0, -1.0)


def _ruido(n, passo=1):
    bruto = rng.uniform(-1, 1, n // passo + 1)
    return np.repeat(bruto, passo)[:n]


def _queda(t, tau):
    return np.exp(-t / tau) * sem_clique(t)


# ---------------------------------------------------------------- sons

def dano():
    """Jogador ferido: grito descendo rápido + estalo áspero. Mais grave e
    mais sujo que o golpe no inimigo, pra não confundir quem apanhou."""
    dur = 0.22
    t = _t(dur)
    voz = _pulso_varrido(700, 120, dur, 0.5, curva=0.6) * _queda(t, 0.08)
    estalo = _ruido(len(t), 4) * _queda(t, 0.03)
    return 0.7 * voz + 0.5 * estalo


def critico():
    """Crítico: estalo seco + "tiim" agudo subindo, que brilha por cima."""
    dur = 0.2
    t = _t(dur)
    estalo = _ruido(len(t), 1) * _queda(t, 0.015)
    tiim = _pulso_varrido(1300, 2100, 0.05, 0.25)
    tiim = np.concatenate([tiim, np.where((t[len(tiim):] * 2100 % 1) < 0.25, 1.0, -1.0)])
    return 0.6 * estalo + 0.5 * tiim * _queda(t, 0.07)


def escudo_quebra():
    """Escudo quebrado: estilhaço de vidro — ruído fino e cacos agudos
    caindo em notas aleatórias."""
    dur = 0.4
    t = _t(dur)
    som = 0.6 * _ruido(len(t), 1) * _queda(t, 0.05)
    for i in range(6):
        inicio = int((0.02 + i * 0.045) * SR)
        f = 2600 - i * 280 + rng.uniform(-150, 150)
        n = int(0.06 * SR)
        tc = np.arange(n) / SR
        caco = np.where((tc * f % 1.0) < 0.125, 1.0, -1.0) * _queda(tc, 0.02)
        fim = min(inicio + n, len(som))
        som[inicio:fim] += 0.35 * caco[: fim - inicio]
    return som


def esquiva():
    """Esquiva: "fiu" — sopro de ruído com um assobio subindo."""
    dur = 0.16
    t = _t(dur)
    sino = np.sin(np.pi * t / dur) ** 2
    sopro = _ruido(len(t), 2) * sino
    assobio = _pulso_varrido(500, 1800, dur, 0.125, curva=1.5) * sino
    return 0.35 * sopro + 0.4 * assobio


def vida_baixa():
    """Vida baixa: "bi-bip" curto, tocado em loop pelo jogo enquanto durar."""
    def bip(f):
        t = _t(0.07)
        return np.where((t * f % 1.0) < 0.5, 1.0, -1.0) * _queda(t, 0.05)
    pausa = np.zeros(int(0.04 * SR))
    return np.concatenate([bip(freq(88)), pausa, bip(freq(84))])


def golpe():
    """Ataque neutro: soco — baque grave com o tom caindo + ruído curto."""
    dur = 0.12
    t = _t(dur)
    baque = _pulso_varrido(320, 70, dur, 0.5, curva=0.5) * _queda(t, 0.05)
    ar = _ruido(len(t), 3) * _queda(t, 0.02)
    return 0.7 * baque + 0.4 * ar


def _nota(midi, dur, duty=0.25, tau=None, vibrato=False):
    """Uma nota de pulso com queda exponencial (tau = None: sem queda)."""
    t = _t(dur)
    f = freq(midi)
    if vibrato:
        f = f * (1 + 0.005 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.1) / 0.1, 0, 1))
    fase = np.cumsum(np.broadcast_to(f, t.shape)) / SR
    onda = np.where((fase % 1.0) < duty, 1.0, -1.0)
    env = np.ones_like(t) if tau is None else np.exp(-t / tau)
    r = min(int(0.008 * SR), len(t))
    env[-r:] *= np.linspace(1, 0, r)
    return onda * env * sem_clique(t)


def _sequencia(notas, **kw):
    """[(midi, duração)] em fila; midi None = pausa."""
    partes = []
    for midi, dur in notas:
        partes.append(np.zeros(int(dur * SR)) if midi is None else _nota(midi, dur, **kw))
    return np.concatenate(partes)


def _somar(*sinais):
    n = max(len(x) for x in sinais)
    total = np.zeros(n)
    for x in sinais:
        total[: len(x)] += x
    return total


def moeda():
    """Moeda: o "plim" clássico — duas notas agudas, a segunda soando."""
    return _somar(_nota(83, 0.05, 0.5), np.concatenate([
        np.zeros(int(0.05 * SR)), _nota(88, 0.3, 0.5, tau=0.1)]))


def cura():
    """Cura: arpejo maior subindo rápido, o último soando um pouco mais."""
    return _sequencia([(72, 0.045), (76, 0.045), (79, 0.045), (84, 0.2)], duty=0.25, tau=0.12)


def item():
    """Item obtido: jingle curto de conquista — três notas em tercina e uma
    longa, com segunda voz em terças e baixo segurando."""
    lead = _sequencia([(76, 0.09), (79, 0.09), (84, 0.09), (88, 0.6)], duty=0.5, tau=0.5)
    voz = _sequencia([(72, 0.09), (76, 0.09), (79, 0.09), (84, 0.6)], duty=0.25, tau=0.5)
    t = _t(0.87)
    baixo = np.concatenate([np.zeros(int(0.27 * SR)),
                            np.where((_t(0.6) * freq(48) % 1.0) < 0.5, 1.0, -1.0)
                            * np.exp(-_t(0.6) / 0.4)])
    return 0.55 * lead + 0.3 * voz + 0.35 * baixo[: len(t)]


def sala_limpa():
    """Sala limpa: alívio — arpejo maior subindo e o acorde soando junto."""
    notas = [67, 71, 74, 79]
    partes = []
    for i, midi in enumerate(notas):
        atraso = np.zeros(int(i * 0.06 * SR))
        partes.append(np.concatenate([atraso, _nota(midi, 0.5 - i * 0.06, 0.25, tau=0.2)]))
    return _somar(*partes)


def sala_tranca():
    """Sala trancando: "DUN-dun" grave, meio tom descendo, com baque."""
    dun = _somar(_nota(45, 0.16, 0.5, tau=0.1), _ruido(int(0.06 * SR), 6) * np.exp(-_t(0.06) / 0.02))
    return np.concatenate([dun, _nota(44, 0.22, 0.5, tau=0.12)])


def sem_dinheiro():
    """Sem dinheiro: "bzzt-bzzt" grave e áspero."""
    zumbido = _nota(35, 0.1, 0.125, tau=0.2) * 0.9
    return np.concatenate([zumbido, np.zeros(int(0.04 * SR)), zumbido])


def boss_entrada():
    """Entrada do chefe: estrondo — ronco grave de ruído, um "BWAAM" descendo
    e duas batidas de tímpano."""
    dur = 1.3
    t = _t(dur)
    ronco = _ruido(len(t), 10) * np.exp(-t / 0.45) * sem_clique(t)
    bwaam = np.concatenate([_pulso_varrido(220, 55, 0.9, 0.5, curva=0.7) * _queda(_t(0.9), 0.35),
                            np.zeros(len(t) - int(0.9 * SR))])

    def timpano(atraso, midi):
        tt = _t(0.4)
        f = freq(midi) * (1 + 0.15 * np.exp(-tt / 0.02))
        fase = np.cumsum(f) / SR
        tri = 2 * np.abs(2 * (fase % 1.0) - 1) - 1
        return np.concatenate([np.zeros(int(atraso * SR)), tri * _queda(tt, 0.13)])

    return _somar(0.5 * ronco, 0.6 * bwaam, 0.7 * timpano(0.0, 40), 0.7 * timpano(0.35, 33))


def evolucao():
    """Evolução: glissando subindo duas oitavas em arpejo e um acorde maior
    brilhando no topo."""
    subida = _sequencia([(m, 0.035) for m in
                         [60, 64, 67, 72, 76, 79, 84, 88, 91, 96]], duty=0.25, tau=0.05)
    acorde = _somar(*[_nota(m, 0.9, 0.125 if m > 80 else 0.25, tau=0.35, vibrato=True)
                      for m in (72, 76, 79, 84)])
    return np.concatenate([subida, acorde])


def atordoado():
    """Atordoado: estrelinhas — três notas agudas tilintando."""
    return _sequencia([(100, 0.06), (96, 0.06), (103, 0.13)], duty=0.125, tau=0.05)


def energia_vazia():
    """Energia vazia: "tuk" seco e grave — o gatilho que falha."""
    t = _t(0.05)
    clique = _ruido(len(t), 2) * _queda(t, 0.006)
    blip = _nota(52, 0.05, 0.5, tau=0.015)
    return 0.6 * clique + 0.6 * blip


def cursor():
    """Cursor de menu: um tique curto e agudo."""
    return _nota(93, 0.035, 0.25, tau=0.015)


def voltar():
    """Voltar: duas notas descendo, o oposto do confirmar."""
    return _sequencia([(88, 0.05), (81, 0.07)], duty=0.25, tau=0.04)


def _ruido_descendo(dur, passo_ini, passo_fim):
    """Ruído cujo "tom" cai com o tempo: o degrau do sample-and-hold cresce
    de [passo_ini] a [passo_fim] — a explosão clássica de console 8 bits."""
    n = int(dur * SR)
    saida = np.empty(n)
    i = 0
    while i < n:
        passo = int(passo_ini + (passo_fim - passo_ini) * (i / n))
        saida[i:i + passo] = rng.uniform(-1, 1)
        i += passo
    return saida


def explosao():
    """Explosão neutra: o estouro clássico, ruído caindo de tom."""
    dur = 0.6
    t = _t(dur)
    return _ruido_descendo(dur, 2, 24) * _queda(t, 0.18)


def explosao_fogo():
    """Explosão de fogo: rugido de ruído grave, ronco descendo e estalos de
    brasa espalhados pela cauda."""
    dur = 0.65
    t = _t(dur)
    rugido = _ruido_descendo(dur, 3, 18) * _queda(t, 0.2)
    ronco = _pulso_varrido(160, 40, dur, 0.5, curva=0.6) * _queda(t, 0.15)
    brasas = np.zeros(len(t))
    for _ in range(9):
        i = int(rng.uniform(0.08, 0.55) * SR)
        n = int(0.012 * SR)
        brasas[i:i + n] += _ruido(n, 1) * np.exp(-np.arange(n) / (0.003 * SR))
    return 0.65 * rugido + 0.35 * ronco + 0.45 * brasas


def explosao_agua():
    """Explosão de água: "bloop" subindo e o chuá de ruído fino caindo, com
    bolhas estourando no fim."""
    dur = 0.6
    t = _t(dur)
    bloop = np.concatenate([_pulso_varrido(180, 900, 0.08, 0.25) * _queda(_t(0.08), 0.06),
                            np.zeros(len(t) - int(0.08 * SR))])
    chua = _ruido(len(t), 1) * np.exp(-t / 0.16) * sem_clique(t) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t))
    bolhas = np.zeros(len(t))
    for k in range(4):
        i = int((0.18 + k * 0.08 + rng.uniform(0, 0.03)) * SR)
        n = int(0.04 * SR)
        f0 = rng.uniform(500, 900)
        bolha = _pulso_varrido(f0, f0 * 2.2, 0.04, 0.5) * np.exp(-np.arange(n) / (0.012 * SR))
        bolhas[i:i + n] += bolha[: len(bolhas[i:i + n])]
    return 0.5 * bloop + 0.55 * chua + 0.3 * bolhas


def explosao_raio():
    """Explosão elétrica: estalo brilhante, zumbido de 60 Hz tremendo e um
    zap descendo."""
    dur = 0.5
    t = _t(dur)
    estalo = _ruido(len(t), 1) * _queda(t, 0.02)
    f = 60 * (1 + 0.4 * rng.uniform(-1, 1, len(t) // 400 + 1).repeat(400)[: len(t)])
    fase = np.cumsum(f) / SR
    zumbido = np.where((fase % 1.0) < 0.25, 1.0, -1.0) * _queda(t, 0.15)
    zap = _pulso_varrido(2200, 180, dur, 0.125, curva=0.4) * _queda(t, 0.1)
    return 0.6 * estalo + 0.45 * zumbido + 0.4 * zap


def explosao_veneno():
    """Explosão de veneno (planta): "blorp" gosmento grave, respingo úmido e
    um borbulhar baixo."""
    dur = 0.6
    t = _t(dur)
    blorp_t = _t(0.25)
    f = 320 * (80 / 320) ** (blorp_t / 0.25)
    fase = np.cumsum(f) / SR
    blorp = np.concatenate([(2 * np.abs(2 * (fase % 1.0) - 1) - 1) * _queda(blorp_t, 0.12),
                            np.zeros(len(t) - len(blorp_t))])
    respingo = _ruido(len(t), 5) * _queda(t, 0.07)
    borbulha = np.zeros(len(t))
    for k in range(5):
        i = int((0.15 + k * 0.07) * SR)
        n = int(0.05 * SR)
        g = _nota(int(rng.uniform(40, 48)), 0.05, 0.5, tau=0.015)
        borbulha[i:i + n] += g[: len(borbulha[i:i + n])]
    return 0.7 * blorp + 0.45 * respingo + 0.25 * borbulha


def boss_derrotado():
    """Chefe derrotado: explosão longa caindo de tom e, por cima, um acorde
    maior subindo em arpejo — a vitória em cima do estrondo."""
    dur = 1.5
    t = _t(dur)
    estrondo = _ruido_descendo(0.9, 2, 30) * _queda(_t(0.9), 0.3)
    estrondo = np.concatenate([estrondo, np.zeros(len(t) - len(estrondo))])
    partes = []
    for i, midi in enumerate([72, 76, 79, 84]):
        atraso = np.zeros(int((0.35 + i * 0.08) * SR))
        partes.append(np.concatenate([atraso, _nota(midi, 1.1 - i * 0.08, 0.5, tau=0.5, vibrato=True)]))
    return _somar(0.7 * estrondo, *[0.3 * p for p in partes])


def campeao():
    """Campeão apareceu: alarme — duas sirenes subindo e um trítono seco."""
    sirene = np.concatenate([_pulso_varrido(300, 600, 0.12, 0.5) * _queda(_t(0.12), 0.2),
                             _pulso_varrido(300, 600, 0.12, 0.5) * _queda(_t(0.12), 0.2)])
    tritono = _somar(_nota(57, 0.25, 0.5, tau=0.1), _nota(63, 0.25, 0.25, tau=0.1))
    return np.concatenate([sirene, tritono])


def escudo_recarga():
    """Escudo recarregado: brilho curto subindo, discreto (repete em combate)."""
    return _sequencia([(88, 0.05), (95, 0.1)], duty=0.125, tau=0.05)


SONS = {
    'dano.wav': (dano, 0.85),
    'critico.wav': (critico, 0.85),
    'escudoQuebra.wav': (escudo_quebra, 0.8),
    'esquiva.wav': (esquiva, 0.7),
    # Baixo de propósito: toca repetindo enquanto a vida estiver no fim.
    'vidaBaixa.wav': (vida_baixa, 0.4),
    'golpe.wav': (golpe, 0.8),
    'moeda.wav': (moeda, 0.6),
    'cura.wav': (cura, 0.65),
    'item.wav': (item, 0.8),
    'salaLimpa.wav': (sala_limpa, 0.65),
    'salaTranca.wav': (sala_tranca, 0.8),
    'semDinheiro.wav': (sem_dinheiro, 0.6),
    'bossEntrada.wav': (boss_entrada, 0.9),
    'evolucao.wav': (evolucao, 0.7),
    'atordoado.wav': (atordoado, 0.55),
    'energiaVazia.wav': (energia_vazia, 0.5),
    'cursor.wav': (cursor, 0.45),
    'voltar.wav': (voltar, 0.5),
    'explosao.wav': (explosao, 0.85),
    'explosaoFogo.wav': (explosao_fogo, 0.85),
    'explosaoAgua.wav': (explosao_agua, 0.8),
    'explosaoRaio.wav': (explosao_raio, 0.8),
    'explosaoVeneno.wav': (explosao_veneno, 0.8),
    'bossDerrotado.wav': (boss_derrotado, 0.9),
    'campeao.wav': (campeao, 0.7),
    'escudoRecarga.wav': (escudo_recarga, 0.45),
}


def salvar(caminho, sinal, pico):
    sinal = np.tanh(sinal * 1.2)
    sinal *= pico / np.max(np.abs(sinal))
    r = int(0.005 * SR)
    sinal[-r:] *= np.linspace(1, 0, r)
    with wave.open(caminho, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((sinal * 32767).astype('<i2').tobytes())
    print(f'{caminho}: {len(sinal) / SR:.2f}s')


if __name__ == '__main__':
    pasta = sys.argv[1]
    for nome, (gerar, pico) in SONS.items():
        salvar(os.path.join(pasta, nome), gerar(), pico)
