enum CreatureType { fogo, planta, agua, eletrico, neutro }

// Ciclo fechado: fogo > planta > elétrico > água > fogo. Cada elemento
// vence um e perde pra outro; os pares de fora do ciclo ficam em 1,0x.
const Map<CreatureType, CreatureType> _vantagens = {
  CreatureType.fogo: CreatureType.planta,
  CreatureType.planta: CreatureType.eletrico,
  CreatureType.agua: CreatureType.fogo,
  CreatureType.eletrico: CreatureType.agua,
};

const Map<CreatureType, CreatureType> _desvantagens = {
  CreatureType.fogo: CreatureType.agua,
  CreatureType.planta: CreatureType.fogo,
  CreatureType.agua: CreatureType.eletrico,
  CreatureType.eletrico: CreatureType.planta,
};

/// Multiplicador de dano de [atacante] contra [defensor].
double typeMultiplier(CreatureType atacante, CreatureType defensor) {
  if (_vantagens[atacante] == defensor) return 2;
  if (_desvantagens[atacante] == defensor) return 0.5;
  return 1.0;
}
