import 'package:creatures_rogue/game/audio/game_audio.dart';
import 'package:creatures_rogue/game/audio/sfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:creatures_rogue/game/components/core/palette.dart';
import 'package:creatures_rogue/game/components/effects/text_effect.dart';
import 'package:creatures_rogue/l10n/l10n_extensions.dart';
import 'collectible.dart';
import 'item_efeito.dart';
import '../player/player.dart';

/// Um balcão da loja: o sprite do que está à venda, com o preço escrito
/// embaixo. Encostar compra.
///
/// O que ele vende vem no callback [entregar], em vez de um enum próprio —
/// assim a loja monta um balcão de consumível, de upgrade ou de cura com a
/// mesma classe, sem duplicar a lógica de cobrança. O callback devolve `false`
/// quando a entrega não deu (inventário cheio, por exemplo), e nesse caso a
/// moeda NÃO é cobrada.
class ShopStand extends Collectible {
  final int preco;
  final bool Function(Player player) entregar;

  /// Aviso quando [entregar] recusa. Varia por balcão: "CHEIO" só faz sentido
  /// pro inventário, e leria errado numa cura recusada por vida cheia. `null`
  /// usa o aviso padrão — resolvido só na hora do uso, via `game.buildContext`,
  /// porque o default de um parâmetro precisa ser constante e `AppLocalizations`
  /// exige `BuildContext`.
  final String? msgFalha;

  /// Texto mostrado ao comprar com sucesso — mesma descrição que o item
  /// mostraria ao ser pego/usado direto (ver `ConsumableTypeData.descricao`
  /// e `PowerUpTypeData.descricao`), pra loja e chão lerem igual.
  final String Function(BuildContext context) descricao;

  /// Monta um balcão NOVO pra este lugar depois de uma compra, quando o
  /// jogador tem `Reposicao`. Nulo = este balcão não se repõe.
  final ShopStand Function()? repor;

  /// O item com gatilho à venda, quando este balcão vende um — só pra marcar
  /// como visto no compêndio.
  final ItemEfeito? itemEfeito;

  bool _visto = false;

  ShopStand({
    required super.position,
    required this.preco,
    required this.entregar,
    required super.spritePath,
    required this.descricao,
    this.msgFalha,
    this.repor,
    this.itemEfeito,
    super.cor1,
    super.cor2,
  });

  static final TextPaint _precoPaint = TextPaint(
    style: const TextStyle(
      fontFamily: 'pixelFont',
      color: Palette.amarelo,
      fontSize: 6,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(color: Palette.preto, offset: Offset(1, 1)),
        Shadow(color: Palette.preto, offset: Offset(-1, -1)),
        Shadow(color: Palette.preto, offset: Offset(1, -1)),
        Shadow(color: Palette.preto, offset: Offset(-1, 1)),
        Shadow(color: Palette.preto, offset: Offset(0, 1)),
        Shadow(color: Palette.preto, offset: Offset(0, -1)),
        Shadow(color: Palette.preto, offset: Offset(1, 0)),
        Shadow(color: Palette.preto, offset: Offset(-1, 0)),
      ],
    ),
  );

  @override
  void update(double dt) {
    super.update(dt);
    final item = itemEfeito;
    if (item != null && !_visto) _visto = registrarSeVisto(this, item);
  }

  /// Comprar toca o jingle de item, seja o que for — é a conquista da
  /// compra, e o "sem dinheiro" sai lá embaixo.
  @override
  Sfx? get somDeColeta => Sfx.item;

  @override
  bool onCollect(Player player) {
    final l = game.buildContext!.l10n;

    final custo = _precoPara(player);
    if (player.coins < custo) {
      GameAudio.instance.play(Sfx.semDinheiro);
      _avisar(l.effect_semMoeda);
      return false; // continua no balcão: dá pra voltar com dinheiro
    }

    if (!entregar(player)) {
      _avisar(msgFalha ?? l.effect_cheio);
      return false;
    }

    player.coins -= custo;
    _avisar(descricao(game.buildContext!));

    // Reposição: um balcão novo no mesmo lugar. Some este e nasce outro, em
    // vez de reaproveitar, porque o produto (e o sprite) pode mudar.
    final novo = repor;
    if (player.lojaRepoe && novo != null) parent?.add(novo());

    return true;
  }

  /// Preço com os descontos do jogador (ver `Cupom`). Nunca de graça.
  int _precoPara(Player player) =>
      (preco * player.fatorPrecoLoja).ceil().clamp(1, preco);


  void _avisar(String texto) {
    parent?.add(
      TextEffect(
        text: texto,
        position: position.clone() + Vector2(0, -12),
        color: Palette.amarelo,
        duration: TextEffect.duracaoLeitura,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _precoPaint.render(
      canvas,
      '${_precoPara(game.player)}',
      Vector2(size.x / 2, size.y + 1),
      anchor: Anchor.topCenter,
    );
  }
}
