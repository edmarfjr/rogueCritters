import 'package:creatures_rogue/game/maldicoes.dart';
import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'collectible.dart';
import 'item_descritor.dart';
import '../player/player.dart';

/// Itens de uso único que ocupam os dois slots do inventário.
///
/// Nenhum deles pede mira: os dois polegares já estão ocupados (joystick de um
/// lado, habilidades do outro), então clicar num slot no meio da briga já custa
/// movimento — pedir alvo em cima disso seria injogável.
///
/// Sprite e cores são campos do próprio valor, não `switch`: criar um
/// consumível novo é UMA linha na lista abaixo mais um `case` em [nome],
/// [descricao] e [aplicar].
///
/// CUIDADO: o `name` de cada valor é a chave que o save grava em `'slots'`.
/// Renomear um valor invalida saves existentes.
///
/// Corpo dentro do enum, e não numa extension: método de extension NÃO conta
/// pra satisfazer [ItemDescritor].
enum ConsumableType implements ItemDescritor {
  pocao('items/potion.png', Palette.indigo, Palette.cinzaEsc),
  escudo('items/escudo.png', Palette.indigo, Palette.royal),
  congelar('items/gelo.png', Palette.azul, Palette.royal),
  mapa('items/mapa.png', Palette.bege, Palette.marrom),
  doce('items/doce.png', Palette.azul, Palette.royal),
  espelho('items/espelho.png', Palette.cinza, Palette.azulEsc);

  const ConsumableType(this.spritePath, this.cor1, this.cor2);

  /// Segundos de reflexão do ESPELHO.
  static const double duracaoEspelho = 10.0;

  @override
  final String spritePath;
  @override
  final Color cor1;
  @override
  final Color cor2;

  @override
  String get id => name;


  /// Texto mostrado acima do jogador quando o item faz efeito de verdade
  /// (ver `aplicar` — nunca aparece se o efeito não teve serventia).
  /// Nome do item. Diferente de [descricao], que conta o EFEITO ("INIMIGOS
  /// CONGELADOS") e só faz sentido depois de usar — no chão o jogador precisa
  /// saber o que é, não o que vai acontecer.
  @override
  String nome(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      ConsumableType.pocao => l.item_pocao,
      ConsumableType.escudo => l.item_escudo,
      ConsumableType.congelar => l.item_congelar,
      ConsumableType.mapa => l.item_mapa,
      ConsumableType.doce => l.item_doce,
      ConsumableType.espelho => l.item_espelho,
    };
  }

  @override
  String descricao(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      ConsumableType.pocao => l.effect_maisVida(2),
      ConsumableType.escudo => l.effect_escudoAtivo,
      ConsumableType.congelar => l.effect_inimigosCongelados,
      ConsumableType.mapa => l.effect_mapaRevelado,
      ConsumableType.doce => '15 XP',//l.effect_doce,
      ConsumableType.espelho => l.effect_espelho,
    };
  }

  /// Efeito no instante em que o slot é clicado. Cada caso reaproveita um
  /// sistema que já existe no Player — nada de mecânica nova por item.
  ///
  /// Devolve `false` quando o efeito não teria serventia nenhuma (poção com
  /// vida cheia, congelar sem inimigo na sala, mapa dentro de sala trancada, em
  /// que o minimapa fica escondido). Nesse caso o `useSlot` NÃO gasta o item —
  /// senão o jogador veria o item desaparecer sem nada acontecer, o que lê como
  /// bug e não como regra.
  bool aplicar(Player player) {
    GameAudio.instance.play(Sfx.use);

    final bool sucesso;
    switch (this) {
      case ConsumableType.pocao:
        sucesso = player.heal(2);
      case ConsumableType.escudo:
        // Escudo sem prazo: empilha com a bolha de habilidade em vez de
        // sobrescrevê-la, e é o ÚLTIMO a ser gasto — golpe leva primeiro o
        // escudo temporário, que ia expirar sozinho de qualquer jeito.
        player.adicionarEscudoPermanente(1);
        sucesso = true;
      case ConsumableType.congelar:
        sucesso = player.congelarInimigos(3.0);
      case ConsumableType.mapa:
        // Com a `Névoa` o mapa revelado nem apareceria: recusa, e o item
        // fica no bolso.
        sucesso =
            !player.temMaldicao(Maldicao.nevoa) && player.revelarMapa();
      case ConsumableType.doce:
        sucesso = player.ganharXp(15);
      case ConsumableType.espelho:
        // Recusa se já está de pé: reaplicar só renovaria a duração, e o
        // jogador veria um item sumir por quase nada. Mesma regra da poção
        // com vida cheia.
        if (player.temEfeito(#espelho)) {
          sucesso = false;
        } else {
          // `refleteProjetil` é o mesmo campo que a habilidade Casco Fechado
          // usa; quem resolve a reflexão é o `Projectile`. Aqui só se liga e
          // desliga o interruptor.
          //
          // Dono padrão (criatura): o espelho é estado de combate e cai junto
          // com o resto numa troca de criatura. É o mesmo tratamento que
          // qualquer buff de combate recebe, e o contrário disso seria o
          // efeito sobreviver a uma criatura que nem estava em campo.
          player.aplicarEfeito(
            #espelho,
            duracaoEspelho,
            aoIniciar: () => player.refleteProjetil = true,
            aoTerminar: () => player.refleteProjetil = false,
          );
          sucesso = true;
        }
    }

    if (sucesso) {
      final context = player.game.buildContext!;
      player.parent?.add(TextEffect(
        text: descricao(context),
        position: player.position.clone() + Vector2(0, -player.size.y / 2 - 4),
        color: Palette.verde,
        duration: TextEffect.duracaoLeitura,
      ));
    }

    return sucesso;
  }
}

/// Coletável no chão que, em vez de aplicar o efeito na hora, entra num slot
/// livre do inventário.
class ConsumablePickup extends Collectible {
  final ConsumableType type;

  ConsumablePickup({required super.position, required ConsumableType tipo})
      : type = tipo,
        super(
          spritePath: tipo.spritePath,
          cor1: tipo.cor1,
          cor2: tipo.cor2,
        );

  @override
  String? nomeExibido(BuildContext context) => type.nome(context);

  @override
  bool onCollect(Player player) {
    final entrou = player.addConsumable(type);

    if (!entrou) {
      // Dois slots cheios: o item fica no chão, mesma regra do coração com HP
      // cheio (ver `Collectible.onCollect`). O aviso existe porque, sem ele,
      // passar por cima e nada acontecer parece bug.
      parent?.add(TextEffect(
        text: game.buildContext!.l10n.effect_cheio,
        position: position.clone() + Vector2(0, -10),
        color: Palette.amarelo,
      ));
    }

    return entrou;
  }
}
