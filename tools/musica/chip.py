"""Síntese chiptune no estilo Game Boy, compartilhada pelas faixas do jogo.

Canais como no Game Boy: pulso (duty 12,5/25/50%), onda de 4 bits e ruído.
Cada faixa monta uma `Faixa`, escreve notas nos canais e chama `salvar`.
"""
import wave

import numpy as np

SR = 32000


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pulso(f, n, duty):
    t = np.arange(n) / SR
    return np.where(((t * f) % 1.0) < duty, 1.0, -1.0)


def pulso_vibrato(f, n, duty, inicio=0.18, profundidade=0.004, hz=5.5):
    """Pulso com vibrato que entra depois de [inicio] segundos."""
    t = np.arange(n) / SR
    vib = 1 + profundidade * np.sin(2 * np.pi * hz * t) * np.clip((t - inicio) / 0.1, 0, 1)
    fase = np.cumsum(f * vib) / SR
    return np.where((fase % 1.0) < duty, 1.0, -1.0)


def onda4bits(f, n):
    """Triângulo quantizado em 16 níveis, como o canal de onda do Game Boy."""
    t = np.arange(n) / SR
    tri = 2 * np.abs(2 * ((t * f) % 1.0) - 1) - 1
    return np.round((tri + 1) * 7.5) / 7.5 - 1


def envelope(n, ataque=0.004, decai=0.15, sustenta=0.7, solta=0.015):
    t = np.arange(n) / SR
    env = np.ones(n)
    a = int(ataque * SR)
    if a:
        env[:a] = np.linspace(0, 1, a)
    env = np.where(t > ataque, sustenta + (1 - sustenta) * np.exp(-(t - ataque) / decai), env)
    r = min(int(solta * SR), n)
    env[n - r:] *= np.linspace(1, 0, r)
    return env


def sem_clique(t):
    """Rampa de 2 ms no começo: golpe que começa no máximo estala."""
    return np.clip(t / 0.002, 0, 1)


class Faixa:
    def __init__(self, bpm, compassos, semente=7):
        self.colcheia = 60.0 / bpm / 2
        self.compassos = compassos
        self.duracao = compassos * 8 * self.colcheia
        self.n = int(round(self.duracao * SR))
        self.canais = {}
        self.rng = np.random.default_rng(semente)

    def canal(self, nome):
        if nome not in self.canais:
            self.canais[nome] = np.zeros(self.n)
        return self.canais[nome]

    def por(self, nome, inicio, sinal):
        canal = self.canal(nome)
        i = int(round(inicio * SR))
        fim = min(i + len(sinal), self.n)
        if fim > i:
            canal[i:fim] += sinal[: fim - i]

    def amostras(self, colcheias):
        return int(round(colcheias * self.colcheia * SR))

    # ------------------------------------------------------------ bateria

    def ruido(self, n, passo):
        """Ruído "travado" em degraus, mais áspero que branco — som de LFSR."""
        bruto = self.rng.uniform(-1, 1, n // passo + 1)
        return np.repeat(bruto, passo)[:n]

    def bumbo(self):
        n = int(0.09 * SR)
        t = np.arange(n) / SR
        f = 140 * np.exp(-t / 0.025) + 45
        fase = np.cumsum(f) / SR
        return np.where((fase % 1) < 0.5, 1.0, -1.0) * np.exp(-t / 0.035) * sem_clique(t)

    def caixa(self):
        n = int(0.12 * SR)
        t = np.arange(n) / SR
        return self.ruido(n, 3) * np.exp(-t / 0.04) * sem_clique(t)

    def chimbal(self, forte=False):
        n = int(0.035 * SR)
        t = np.arange(n) / SR
        return self.ruido(n, 1) * np.exp(-t / 0.012) * (0.6 if forte else 0.35) * sem_clique(t)

    def timpano(self, midi, dur=0.35):
        """Tímpano: triângulo grave com o tom caindo um pouco no ataque."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = freq(midi) * (1 + 0.15 * np.exp(-t / 0.02))
        fase = np.cumsum(f) / SR
        tri = 2 * np.abs(2 * (fase % 1.0) - 1) - 1
        return tri * np.exp(-t / (dur / 3)) * sem_clique(t)

    def prato(self, dur=0.9):
        """Prato de ataque: ruído fino com cauda longa."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        return self.ruido(n, 1) * np.exp(-t / (dur / 4)) * sem_clique(t)

    # ------------------------------------------------------------ saída

    def mixar(self, volumes, pico=0.85, fade_fim=0.0):
        """[fade_fim] segundos de queda no fim: pra faixa cuja cauda (eco,
        nota longa) ainda soa no último quadro, e estalaria ao voltar pro
        começo do loop."""
        mix = sum(v * self.canal(nome) for nome, v in volumes.items())
        mix = np.tanh(mix * 1.2)
        mix = mix * (pico / np.max(np.abs(mix)))
        r = int(fade_fim * SR)
        if r:
            mix[-r:] *= np.linspace(1, 0, r)
        return mix

    def salvar(self, caminho, volumes, fade_fim=0.0):
        mix = self.mixar(volumes, fade_fim=fade_fim)
        with wave.open(caminho, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((mix * 32767).astype('<i2').tobytes())
        print(f'{caminho}: {self.duracao:.1f}s')
