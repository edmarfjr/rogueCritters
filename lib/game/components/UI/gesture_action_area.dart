import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:creatures_rogue/game/components/UI/consumable_slot_button.dart';

/// Esquema de controle alternativo aos três botões — uma área invisível (na
/// prática, a metade direita da tela) onde o TIPO do gesto escolhe a ação
/// (PIVOT_CONTROLE_DIRETO.md §2.7):
///
/// - Toque parado (e mantido) dispara [onAbility1HoldChanged] — a habilidade
///   A do jogador, com o mesmo hold contínuo que o esquema de botões usa
///   (dispara de novo sozinha assim que o cooldown zerar, enquanto o dedo
///   continuar parado).
/// - Arrastar o dedo pra CIMA dispara [onAbility2] — uma vez só por arraste,
///   a habilidade B. Sem hold contínuo aqui (limitação conhecida do gesto:
///   ver o doc) — pra manter disparando, o jogador solta e arrasta de novo.
/// - Arrastar o dedo pra BAIXO dispara [onDodge] — uma vez só, a esquiva
///   pessoal do jogador.
/// - Arrastar na diagonal ou de lado não faz nada: sem eixo dominante claro,
///   melhor não adivinhar do que disparar a ação errada.
///
/// A separação toque-parado/arraste sai de graça do próprio Flutter: o
/// `ImmediateMultiDragGestureRecognizer` só promove um toque a arraste depois
/// que o dedo anda mais que `kTouchSlop` (~18px). Até lá o gesto é um tap; a
/// partir dali o tap é cancelado e o arraste assume — então "parado" e
/// "arrastando" já são estados mutuamente exclusivos decididos pela arena de
/// gestos, sem precisar de limiar próprio pra essa parte.
///
/// A classificação de DIREÇÃO do arraste (cima/baixo) é nossa: acumula o
/// deslocamento total desde o início do arraste, e assim que ultrapassa
/// [_limiarDirecao] classifica pelo eixo dominante NAQUELE instante e
/// dispara uma vez — o gesto não reavalia depois disso até o dedo soltar e
/// um toque novo começar. Reavaliar continuamente deixaria um arraste que
/// começa ambíguo (diagonal) e endireita depois disparar tarde, ou pior,
/// disparar de novo se o dedo mudar de direção no meio do caminho.
///
/// O estado é por ponteiro, não global: dois dedos na metade direita agem
/// independentes.
class GestureActionArea extends PositionComponent
    with TapCallbacks, DragCallbacks {
  final void Function(bool active) onAbility1HoldChanged;
  final VoidCallback onAbility2;
  final VoidCallback onDodge;

  static const double _limiarDirecao = 20.0;

  final Set<int> _holdPointers = {};
  bool _holdActive = false;

  final Map<int, Vector2> _arrasteAcumulado = {};
  final Set<int> _classificados = {};

  GestureActionArea({
    required this.onAbility1HoldChanged,
    required this.onAbility2,
    required this.onDodge,
    super.priority,
  });

  @override
  // `canvasSize`, e não `size`: o corpo atribui o `size` do PRÓPRIO
  // componente, e um parâmetro com esse nome o esconderia.
  // ignore: avoid_renaming_method_parameters
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    // Metade direita da tela, abaixo da faixa reservada do topo — mesma
    // razão do DynamicJoystickComponent (metade esquerda) e do
    // `ConsumableSlotButton.alturaFaixa`: sem essa exclusão, um toque num
    // slot de inventário também cairia aqui.
    size = Vector2(canvasSize.x / 2, canvasSize.y - ConsumableSlotButton.alturaFaixa);
    position = Vector2(canvasSize.x / 2, ConsumableSlotButton.alturaFaixa);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _holdPointers.add(event.pointerId);
    _arrasteAcumulado[event.pointerId] = Vector2.zero();
    _atualizarHold();
  }

  @override
  void onTapUp(TapUpEvent event) => _soltarPonteiro(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) => _soltarPonteiro(event.pointerId);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // O toque parado deste dedo virou arraste — sai do canal de hold (a
    // arena de gestos já decidiu que isto não é mais um toque parado).
    _holdPointers.remove(event.pointerId);
    _atualizarHold();
    _arrasteAcumulado[event.pointerId] = Vector2.zero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final id = event.pointerId;
    if (_classificados.contains(id)) return;

    final acumulado = _arrasteAcumulado[id];
    if (acumulado == null) return;
    acumulado.add(event.localDelta);

    if (acumulado.length < _limiarDirecao) return;

    _classificados.add(id);

    onAbility2();
    /* use abaixo casi for usar 2 comandos de arraste
    if (acumulado.y.abs() <= acumulado.x.abs()) return; // lateral/diagonal: sem ação

    if (acumulado.y < 0) {
      onAbility2();
    } else {
      onDodge();
    }
    */
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _limparPonteiro(event.pointerId);
  }

  void _soltarPonteiro(int pointerId) {
    _holdPointers.remove(pointerId);
    _atualizarHold();
    _limparPonteiro(pointerId);
  }

  void _limparPonteiro(int pointerId) {
    _arrasteAcumulado.remove(pointerId);
    _classificados.remove(pointerId);
  }

  void _atualizarHold() {
    final ativo = _holdPointers.isNotEmpty;
    if (ativo == _holdActive) return;
    _holdActive = ativo;
    onAbility1HoldChanged(ativo);
  }
}
