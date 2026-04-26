import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ietipark_web/gt_compat/test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final String serverUrl = 'ws://localhost:3000';

void main() {
  runApp(const MyApp());
}

Future<GameData> loadGameData() async {
  final String response =
      await rootBundle.loadString('assets/game_data.json');
  final Map<String, dynamic> json = jsonDecode(response);
  return GameData.fromJson(json);
}

Future<TileMap> loadTileMap(String path) async {
  final String response = await rootBundle.loadString('assets/$path');
  final Map<String, dynamic> json = jsonDecode(response);
  return TileMap.fromJson(json);
}

// ── Datos cargados para una TileLayer ─────────────────────
class LoadedLayer {
  final TileLayer layer;
  final TileMap tileMap;
  final ui.Image atlas;
  final int atlasColumns;

  const LoadedLayer({
    required this.layer,
    required this.tileMap,
    required this.atlas,
    required this.atlasColumns,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    wasawasa();
    return MaterialApp(
      title: 'IetiPark Scenario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Game Scenario'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, dynamic>> clients = [];
  Map<String, dynamic> currentLevel = {};
  WebSocketChannel? _channel;
  bool isLoading = true;
  String? errorMessage;
  GameData? gameData;

  @override
  void initState() {
    super.initState();
    _loadGameDataAndConnect();
  }

  Future<void> _loadGameDataAndConnect() async {
    try {
      final data = await loadGameData();
      setState(() => gameData = data);
    } catch (e) {
      print('Error cargando game_data.json: $e');
    }
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _channel!.stream.listen(
        (message) {
          try {
            print('Mensaje WebSocket recibido: $message');
            final data = jsonDecode(message) as Map<String, dynamic>;
            if (data['type'] == 'GAME STATE') {
              final payload = data['payload'] as Map<String, dynamic>;
              setState(() {
                clients = List<Map<String, dynamic>>.from(payload['players']);
                currentLevel = Map<String, dynamic>.from(payload['currentLevel']);
                isLoading = false;
                errorMessage = null;
              });
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          setState(() {
            errorMessage = 'Error de conexión WebSocket: $error';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
        onDone: () {
          setState(() {
            errorMessage = 'Conexión WebSocket cerrada';
            isLoading = false;
          });
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error al conectar: $e';
        isLoading = false;
      });
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _connectWebSocket();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: GameScenario(
        clients: clients,
        gameData: gameData,
        currentLevel: currentLevel,
      ),
    );
  }
}

// ── GameScenario ──────────────────────────────────────────
class GameScenario extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final GameData? gameData;
  final Map<String, dynamic> currentLevel;

  const GameScenario({
    super.key,
    required this.clients,
    this.gameData,
    this.currentLevel = const {},
  });

  @override
  State<GameScenario> createState() => _GameScenarioState();
}

class _GameScenarioState extends State<GameScenario> {
  List<LoadedLayer?> _loadedLayers = [];
  bool _layersReady = false;
  Level? _activeLevel;

  double get viewportWidth =>
      _activeLevel?.viewportWidth.toDouble() ?? 800;
  double get viewportHeight =>
      _activeLevel?.viewportHeight.toDouble() ?? 480;

  Color get backgroundColor {
    final hex = _activeLevel?.backgroundColorHex ?? '#CCCCCC';
    final buffer = StringBuffer()
      ..write('ff')
      ..write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _resolveActiveLevel();
    _loadAllLayers();
  }

  @override
  void didUpdateWidget(GameScenario oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLevelName = widget.currentLevel['name'] as String?;
    final oldLevelName = oldWidget.currentLevel['name'] as String?;
    if (newLevelName != oldLevelName) {
      _resolveActiveLevel();
      _loadAllLayers();
    }
  }

  void _resolveActiveLevel() {
    final currentLevelName = widget.currentLevel['name'] as String?;
    _activeLevel = widget.gameData?.levels.firstWhere(
      (l) => l.name == currentLevelName,
      orElse: () => widget.gameData!.levels.first,
    );
  }

  Future<void> _loadAllLayers() async {
    if (_activeLevel == null) {
      setState(() => _layersReady = true);
      return;
    }

    setState(() => _layersReady = false);

    final layers = _activeLevel!.layers
        .where((l) => l.visible)
        .toList()
        .reversed
        .toList();

    final futures = layers.map(_loadSingleLayer).toList();
    final results = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _loadedLayers = results;
        _layersReady = true;
      });
    }
  }

  Future<LoadedLayer?> _loadSingleLayer(TileLayer tileLayer) async {
    try {
      final tileMap = await loadTileMap(tileLayer.tileMapFile);
      final ByteData data =
          await rootBundle.load('assets/${tileLayer.tilesSheetFile}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final atlasColumns = image.width ~/ tileLayer.tilesWidth;

      return LoadedLayer(
        layer: tileLayer,
        tileMap: tileMap,
        atlas: image,
        atlasColumns: atlasColumns,
      );
    } catch (e) {
      print('Error cargando TileLayer "${tileLayer.name}": $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyTaken = widget.currentLevel['isKeyTaken'] == true;

    // Sprites estáticos: todo excepto quixote; oculta la llave si ya fue tomada
    final staticSprites = _activeLevel?.sprites
            .where((s) => s.type != 'quixote')
            .where((s) => s.type != 'key' || !isKeyTaken)
            .toList() ??
        [];

    final quixoteSprite = _activeLevel?.sprites.firstWhere(
      (s) => s.type == 'quixote',
      orElse: () => Sprite(
        name: 'quixote',
        gameplayData: '',
        type: 'quixote',
        animationId: '',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
        imageFile: 'media/quixote_1.png',
        flipX: false,
        flipY: false,
        depth: 0,
        groupId: '__main__',
      ),
    );

    // Llave para dibujar sobre el jugador que la lleva
    final Sprite? keySprite = isKeyTaken
        ? _activeLevel?.sprites.cast<Sprite?>().firstWhere(
            (s) => s?.type == 'key',
            orElse: () => null,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Stack(
              children: [
                // ── 1. Color de fondo ─────────────────────────────
                Container(color: backgroundColor),

                // ── 2. TileLayers en orden del JSON ───────────────
                if (_layersReady)
                  ..._loadedLayers.map((ll) {
                    if (ll == null) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: TileMapPainter(
                        tileMap: ll.tileMap,
                        atlas: ll.atlas,
                        tileWidth: ll.layer.tilesWidth,
                        tileHeight: ll.layer.tilesHeight,
                        atlasColumns: ll.atlasColumns,
                        offsetX: ll.layer.x.toDouble(),
                        offsetY: ll.layer.y.toDouble(),
                      ),
                      size: Size(viewportWidth, viewportHeight),
                    );
                  }),

                // ── 3. Sprites estáticos del JSON ─────────────────
                ...staticSprites.map((sprite) => Positioned(
                      left: sprite.x.toDouble(),
                      top: sprite.y.toDouble(),
                      child: _buildStaticSprite(
                        'assets/${sprite.imageFile}',
                        sprite.width.toDouble(),
                        sprite.height.toDouble(),
                      ),
                    )),

                // ── 4. Clientes dinámicos del WebSocket ───────────
                ...widget.clients.map((client) {
                  final pixelX = (client['x'] as num).toDouble();
                  final pixelY = (client['y'] as num).toDouble();
                  final spriteW = (quixoteSprite?.width ?? 32).toDouble();
                  final spriteH = (quixoteSprite?.height ?? 32).toDouble();
                  final hasKey = client['hasKey'] == true;

                  return Positioned(
                    left: pixelX - spriteW / 2,
                    bottom: viewportHeight - pixelY,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          client['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            // ── Personaje ─────────────────────────
                            SizedBox(
                              width: spriteW,
                              height: spriteH,
                              child: Image.asset(
                                'assets/media/quixote_1.png',
                                fit: BoxFit.cover,
                                isAntiAlias: false,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue[400],
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: const Icon(Icons.person,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                            // ── Llave encima del personaje ─────────
                            if (hasKey && keySprite != null)
                              Positioned(
                                top: -keySprite.height.toDouble(),
                                child: Image.asset(
                                  'assets/${keySprite.imageFile}',
                                  width: keySprite.width.toDouble(),
                                  height: keySprite.height.toDouble(),
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.vpn_key,
                                    size: 16,
                                    color: Colors.yellow,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaticSprite(String path, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image, size: width, color: Colors.grey),
      ),
    );
  }
}

// ── TileMapPainter ────────────────────────────────────────
class TileMapPainter extends CustomPainter {
  final TileMap tileMap;
  final ui.Image atlas;
  final int tileWidth;
  final int tileHeight;
  final int atlasColumns;
  final double offsetX;
  final double offsetY;

  TileMapPainter({
    required this.tileMap,
    required this.atlas,
    required this.tileWidth,
    required this.tileHeight,
    required this.atlasColumns,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    final rows = tileMap.tileMap;

    for (int row = 0; row < rows.length; row++) {
      for (int col = 0; col < rows[row].length; col++) {
        final tileIndex = rows[row][col];
        if (tileIndex == -1) continue;

        final atlasCol = tileIndex % atlasColumns;
        final atlasRow = tileIndex ~/ atlasColumns;

        final src = Rect.fromLTWH(
          (atlasCol * tileWidth).toDouble(),
          (atlasRow * tileHeight).toDouble(),
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        final dst = Rect.fromLTWH(
          offsetX + (col * tileWidth).toDouble(),
          offsetY + (row * tileHeight).toDouble(),
          tileWidth.toDouble(),
          tileHeight.toDouble(),
        );

        canvas.drawImageRect(atlas, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(TileMapPainter old) =>
      old.tileMap != tileMap ||
      old.atlas != atlas ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY;
}

// ── GridPainter ───────────────────────────────────────────
class GridPainter extends CustomPainter {
  static const double gridSize = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int i = 0; i <= gridSize.toInt(); i++) {
      canvas.drawLine(
          Offset(i * cellWidth, 0), Offset(i * cellWidth, size.height), paint);
      canvas.drawLine(
          Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}