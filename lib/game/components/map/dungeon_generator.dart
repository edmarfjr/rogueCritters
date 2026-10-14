import 'dart:math';

/// `boss` e `stairs` são a MESMA sala em papéis diferentes: a última do andar,
/// onde nasce a escada pro andar seguinte. A diferença é se há luta antes —
/// em andar de boss é `boss`, nos outros é `stairs`. Separar os dois é o que
/// deixa o minimapa avisar qual dos dois espera o jogador lá.
enum RoomType { start, normal, boss, stairs, item, shop, desafio, evento, secreta }

/// Origem do grid lógico de salas: a sala inicial nasce em (origem, origem),
/// e todo lugar que converte entre índice relativo do jogador
/// (`currentRoomIndex`, que começa em 0,0) e chave absoluta do grid soma
/// esta constante — pra nunca mais dessincronizar como já aconteceu.
const int dungeonGridOrigin = 20;

class RoomData {
  final int x;
  final int y;
  RoomType type;
  
  bool doorTop = false;
  bool doorBottom = false;
  bool doorLeft = false;
  bool doorRight = false;
  bool isCleared = false;
  bool isVisited = false;

  /// Marcada pelo item MAPA: aparece no minimapa sem o jogador ter entrado.
  /// Campo separado de [isVisited] de propósito — `isVisited` decide se a sala
  /// tranca ao entrar e se as portas nascem abertas, então reaproveitá-lo pra
  /// revelar faria o mapa "limpar" a dungeon inteira.
  bool isRevealed = false;

  /// Lados desta sala com a passagem pra sala SECRETA, disfarçada de parede
  /// rachada. Não são portas: o `door*` do mesmo lado só liga quando a
  /// parede quebra (ver `RoomComponent._golpeNaParedeSecreta`) — é o que
  /// esconde a sala secreta e a passagem no minimapa até lá.
  bool paredeSecretaTop = false;
  bool paredeSecretaBottom = false;
  bool paredeSecretaLeft = false;
  bool paredeSecretaRight = false;

  RoomData(this.x, this.y, {this.type = RoomType.normal});
  
  int get doorCount => (doorTop ? 1 : 0) + (doorBottom ? 1 : 0) + (doorLeft ? 1 : 0) + (doorRight ? 1 : 0);
}

class DungeonGenerator {
  final int maxRooms;
  final Random _random = Random();

  static const List<List<int>> _direcoes = [[0, -1], [0, 1], [-1, 0], [1, 0]];

  /// [comBoss] decide se a sala final do andar nasce como [RoomType.boss] ou
  /// [RoomType.stairs]. Quem sabe disso é o jogo (`isBossFloor`), não o
  /// gerador — por isso entra por parâmetro.
  ///
  /// Tem que bater com o `bossBuilder` que o jogo passa pro `RoomComponent`:
  /// os dois saem do mesmo `isBossFloor`. Se discordarem, a sala marcada como
  /// boss não teria quem invocar.
  DungeonGenerator({this.maxRooms = 15, this.comBoss = true});

  final bool comBoss;

  /// Chance de o andar ter uma sala de evento. Andar de boss nunca tem.
  static const double chanceEvento = 0.6;

  /// Chance de o andar ter uma sala secreta.
  static const double chanceSecreta = 0.6;

  Map<String, RoomData> generate() {
    Map<String, RoomData> grid = {};
    List<RoomData> roomQueue = [];

    var startRoom = RoomData(dungeonGridOrigin, dungeonGridOrigin, type: RoomType.start);
    startRoom.isCleared = true;
    startRoom.isVisited = true;
    grid['$dungeonGridOrigin,$dungeonGridOrigin'] = startRoom;
    roomQueue.add(startRoom);

    int roomCount = 1;

    while (roomCount < maxRooms) {
      if (roomQueue.isEmpty) {
        // A expansão é probabilística (50% por direção), então a fila pode
        // secar muito antes de `maxRooms`. No pior caso a própria sala inicial
        // sorteia "não" nas quatro direções (6,25% das vezes) e o andar nasce
        // com uma sala só — sem beco sem-saída, ou seja, sem boss e sem saída
        // do andar. Quando a fila seca, forçamos uma sala nova a partir de
        // qualquer sala que ainda tenha vizinho livre, até bater `maxRooms`.
        final expansiveis = grid.values
            .where((r) => _direcoesLivres(grid, r).isNotEmpty)
            .toList();
        if (expansiveis.isEmpty) break;

        final origem = expansiveis[_random.nextInt(expansiveis.length)];
        final livres = _direcoesLivres(grid, origem);
        roomQueue.add(
            _criarSala(grid, origem, livres[_random.nextInt(livres.length)]));
        roomCount++;
        continue;
      }

      RoomData current = roomQueue.removeAt(0);
      
      final directions = List<List<int>>.from(_direcoes)..shuffle(_random);

      for (var dir in directions) {
        if (roomCount >= maxRooms) break;
        
        if (_random.nextDouble() > 0.5) {
          if (grid.containsKey('${current.x + dir[0]},${current.y + dir[1]}')) {
            continue;
          }
          roomQueue.add(_criarSala(grid, current, dir));
          roomCount++;
        }
      }
    }
    
    _assignSpecialRooms(grid);
    if (_random.nextDouble() < chanceSecreta) _colocarSalaSecreta(grid);

    return grid;
  }

  /// Sala secreta numa célula VAZIA vizinha de salas existentes, de
  /// preferência de duas ou mais (como no Isaac: o lugar "óbvio" pra quem
  /// procura). Liga só a uma delas, a anfitriã, pela parede rachada.
  /// Boss e escada ficam de fora como anfitriãs: a parede deles é a última
  /// sala do andar, e a sala secreta seria achada sem querer na saída.
  void _colocarSalaSecreta(Map<String, RoomData> grid) {
    bool podeHospedar(RoomData r) =>
        r.type != RoomType.boss && r.type != RoomType.stairs;

    final candidatas = <String, List<RoomData>>{};
    for (final sala in grid.values) {
      if (!podeHospedar(sala)) continue;
      for (final d in _direcoes) {
        final chave = '${sala.x + d[0]},${sala.y + d[1]}';
        if (grid.containsKey(chave)) continue;
        candidatas.putIfAbsent(chave, () => []).add(sala);
      }
    }
    if (candidatas.isEmpty) return;

    final melhor = candidatas.values.map((v) => v.length).reduce(max);
    final escolhidas = candidatas.entries
        .where((e) => e.value.length == melhor)
        .toList();
    final escolhida = escolhidas[_random.nextInt(escolhidas.length)];
    final anfitria = escolhida.value[_random.nextInt(escolhida.value.length)];

    final partes = escolhida.key.split(',');
    final secreta = RoomData(
      int.parse(partes[0]),
      int.parse(partes[1]),
      type: RoomType.secreta,
    )..isCleared = true;

    final dx = secreta.x - anfitria.x;
    final dy = secreta.y - anfitria.y;
    if (dx == 1) {
      anfitria.paredeSecretaRight = true;
      secreta.doorLeft = true;
    } else if (dx == -1) {
      anfitria.paredeSecretaLeft = true;
      secreta.doorRight = true;
    } else if (dy == 1) {
      anfitria.paredeSecretaBottom = true;
      secreta.doorTop = true;
    } else {
      anfitria.paredeSecretaTop = true;
      secreta.doorBottom = true;
    }
    grid[escolhida.key] = secreta;
  }

  /// Direções a partir de [room] cuja célula vizinha ainda está vazia.
  List<List<int>> _direcoesLivres(Map<String, RoomData> grid, RoomData room) =>
      _direcoes
          .where((d) => !grid.containsKey('${room.x + d[0]},${room.y + d[1]}'))
          .toList();

  /// Cria a sala vizinha de [origem] na direção [dir], já ligando as portas dos
  /// dois lados, e registra ela no grid.
  RoomData _criarSala(
      Map<String, RoomData> grid, RoomData origem, List<int> dir) {
    final nova = RoomData(origem.x + dir[0], origem.y + dir[1]);

    if (dir[0] == 0 && dir[1] == -1) {
      origem.doorTop = true; nova.doorBottom = true;
    } else if (dir[0] == 0 && dir[1] == 1) {
      origem.doorBottom = true; nova.doorTop = true;
    } else if (dir[0] == -1 && dir[1] == 0) {
      origem.doorLeft = true; nova.doorRight = true;
    } else {
      origem.doorRight = true; nova.doorLeft = true;
    }

    grid['${nova.x},${nova.y}'] = nova;
    return nova;
  }
  
  void _assignSpecialRooms(Map<String, RoomData> grid) {
    List<RoomData> deadEnds = grid.values.where((r) => r.doorCount == 1 && r.type != RoomType.start).toList();
    
    if (deadEnds.isNotEmpty) {
      var bossRoom = deadEnds.removeLast();
      bossRoom.type = comBoss ? RoomType.boss : RoomType.stairs;
      
      if (deadEnds.isNotEmpty) {
        var itemRoom = deadEnds.removeLast();
        itemRoom.type = RoomType.item;
      }

      // Loja: beco sem-saída, se ainda sobrou algum. Senão, qualquer sala
      // comum serve — um andar sem loja deixaria as moedas juntadas nele sem
      // onde ser gastas, e o boss e o tesouro já consumiram os becos.
      RoomData? shopRoom;
      if (deadEnds.isNotEmpty) {
        shopRoom = deadEnds.removeLast();
      } else {
        final comuns =
            grid.values.where((r) => r.type == RoomType.normal).toList();
        if (comuns.isNotEmpty) shopRoom = comuns.last;
      }

      // Desafio: só se ainda sobrou beco sem-saída depois de boss, tesouro e
      // loja. Sala opcional de verdade — andar apertado simplesmente não tem
      // uma, e forçá-la numa sala de passagem faria o jogador cair na briga
      // sem escolher.
      if (deadEnds.isNotEmpty) {
        final desafio = deadEnds.removeLast();
        desafio.type = RoomType.desafio;
        // Nasce limpa como a loja: a sala só tranca quando o jogador PEGA o
        // item do pedestal, não ao entrar.
        desafio.isCleared = true;
      }

      // Evento: beco sem-saída que sobrou, senão qualquer sala comum — ele
      // não tranca nem tem briga, então pode ficar no meio do caminho.
      if (!comBoss && _random.nextDouble() < chanceEvento) {
        RoomData? eventoRoom;
        if (deadEnds.isNotEmpty) {
          eventoRoom = deadEnds.removeLast();
        } else {
          final comuns = grid.values
              .where((r) => r.type == RoomType.normal && r != shopRoom)
              .toList();
          if (comuns.isNotEmpty) {
            eventoRoom = comuns[_random.nextInt(comuns.length)];
          }
        }
        if (eventoRoom != null) {
          eventoRoom.type = RoomType.evento;
          eventoRoom.isCleared = true;
        }
      }

      if (shopRoom != null) {
        shopRoom.type = RoomType.shop;
        // Loja já nasce limpa, como a sala inicial: sem isso ela trancaria e
        // geraria inimigos ao entrar, e o jogador brigaria dentro da loja. É
        // também o que faz as portas dela nascerem abertas.
        shopRoom.isCleared = true;
      }
    }
  }
}
