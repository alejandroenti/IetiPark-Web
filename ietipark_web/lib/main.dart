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
  final String response = await rootBundle.loadString('assets/game_data.json');
  final Map<String, dynamic> json = jsonDecode(response);
  return GameData.fromJson(json);
}

Future<TileMap> loadTileMap(String path) async {
  final String response = await rootBundle.loadString('assets/$path');
  final Map<String, dynamic> json = jsonDecode(response);
  return TileMap.fromJson(json);
}

Future<AnimationsData> loadAnimations(String path) async {
  final String response = await rootBundle.loadString('assets/$path');
  final Map<String, dynamic> json = jsonDecode(response);
  return AnimationsData.fromJson(json);
}

// ── Modelos de Animación ──────────────────────────────────

class AnimationDef {
  final String id;
  final String name;
  final String mediaFile;
  final int startFrame;
  final int endFrame;
  final double fps;
  final bool loop;
  final double anchorX;
  final double anchorY;

  const AnimationDef({
    required this.id,
    required this.name,
    required this.mediaFile,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
    required this.anchorX,
    required this.anchorY,
  });

  int get frameCount => endFrame - startFrame + 1;

  factory AnimationDef.fromJson(Map<String, dynamic> json) {
    return AnimationDef(
      id: json['id'] as String,
      name: json['name'] as String,
      mediaFile: json['mediaFile'] as String,
      startFrame: (json['startFrame'] as num).toInt(),
      endFrame: (json['endFrame'] as num).toInt(),
      fps: (json['fps'] as num).toDouble(),
      loop: json['loop'] as bool,
      anchorX: (json['anchorX'] as num).toDouble(),
      anchorY: (json['anchorY'] as num).toDouble(),
    );
  }
}

class AnimationsData {
  final List<AnimationDef> animations;

  const AnimationsData({required this.animations});

  factory AnimationsData.fromJson(Map<String, dynamic> json) {
    final list = (json['animations'] as List<dynamic>)
        .map((e) => AnimationDef.fromJson(e as Map<String, dynamic>))
        .toList();
    return AnimationsData(animations: list);
  }

  AnimationDef? findById(String id) {
    try {
      return animations.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
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

// ── Imagen de animación lista para pintar ─────────────────
class LoadedAnimation {
  final AnimationDef def;
  final ui.Image sheet;
  /// Anchura de un frame individual en píxeles (= sheet.width / frameCount si hay más de 1 col)
  final int frameWidth;
  final int frameHeight;

  const LoadedAnimation({
    required this.def,
    required this.sheet,
    required this.frameWidth,
    required this.frameHeight,
  });

  /// Columnas del spritesheet (frames en horizontal)
  int get columns => sheet.width ~/ frameWidth;

  /// Devuelve el Rect de origen en el atlas para el frame dado (0-based dentro de la anim)
  Rect srcRect(int localFrame) {
    final absFrame = def.startFrame + localFrame;
    final col = absFrame % columns;
    final row = absFrame ~/ columns;
    return Rect.fromLTWH(
      (col * frameWidth).toDouble(),
      (row * frameHeight).toDouble(),
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
  }
}

// ── MyApp ─────────────────────────────────────────────────
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

// ── MyHomePage ────────────────────────────────────────────
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
  AnimationsData? animationsData;

  @override
  void initState() {
    super.initState();
    _loadGameDataAndConnect();
  }

  Future<void> _loadGameDataAndConnect() async {
    try {
      final data = await loadGameData();
      setState(() => gameData = data);
      // Cargamos también el JSON de animaciones
      final animFile = data.animationsFile;
      if (animFile != null && animFile.isNotEmpty) {
        final anims = await loadAnimations(animFile);
        setState(() => animationsData = anims);
      }
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
                clients =
                    List<Map<String, dynamic>>.from(payload['players']);
                currentLevel =
                    Map<String, dynamic>.from(payload['currentLevel']);
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
        animationsData: animationsData,
        currentLevel: currentLevel,
      ),
    );
  }
}

// ── GameScenario ──────────────────────────────────────────
class GameScenario extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final GameData? gameData;
  final AnimationsData? animationsData;
  final Map<String, dynamic> currentLevel;

  const GameScenario({
    super.key,
    required this.clients,
    this.gameData,
    this.animationsData,
    this.currentLevel = const {},
  });

  @override
  State<GameScenario> createState() => _GameScenarioState();
}

class _GameScenarioState extends State<GameScenario> {
  List<LoadedLayer?> _loadedLayers = [];
  bool _layersReady = false;
  Level? _activeLevel;

  // Cache de animaciones cargadas: animationId -> LoadedAnimation
  final Map<String, LoadedAnimation?> _animCache = {};

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
    _preloadSpriteAnimations();
  }

  @override
  void didUpdateWidget(GameScenario oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLevelName = widget.currentLevel['name'] as String?;
    final oldLevelName = oldWidget.currentLevel['name'] as String?;
    if (newLevelName != oldLevelName) {
      _resolveActiveLevel();
      _loadAllLayers();
      _preloadSpriteAnimations();
    }
  }

  void _resolveActiveLevel() {
    final currentLevelName = widget.currentLevel['name'] as String?;
    _activeLevel = widget.gameData?.levels.firstWhere(
      (l) => l.name == currentLevelName,
      orElse: () => widget.gameData!.levels.first,
    );
  }

  // ── Precarga las animaciones de los sprites del nivel activo ──
  Future<void> _preloadSpriteAnimations() async {
    if (_activeLevel == null || widget.animationsData == null) return;

    for (final sprite in _activeLevel!.sprites) {
      if (sprite.animationId.isEmpty) continue;
      if (_animCache.containsKey(sprite.animationId)) continue;

      final animDef =
          widget.animationsData!.findById(sprite.animationId);
      if (animDef == null) {
        _animCache[sprite.animationId] = null;
        continue;
      }

      final loaded =
          await _loadAnimation(animDef, sprite.width, sprite.height);
      if (mounted) {
        setState(() => _animCache[sprite.animationId] = loaded);
      }
    }
  }

  /// Carga el spritesheet de una animación y calcula el tamaño de frame.
  /// [spriteW] y [spriteH] son las dimensiones del sprite en el JSON del nivel
  /// y se usan como tamaño de frame cuando la imagen tiene un solo frame.
  Future<LoadedAnimation?> _loadAnimation(
      AnimationDef def, int spriteW, int spriteH) async {
    try {
      final ByteData data =
          await rootBundle.load('assets/${def.mediaFile}');
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // El frame width = ancho del tile definido en mediaAssets.
      // Lo calculamos dividiendo el sheet entre el número total de frames
      // posibles en horizontal usando el spriteW del sprite JSON como tile.
      // Si no encaja, usamos el ancho completo de la imagen.
      final totalFrames = def.endFrame + 1;
      final frameWidth = (image.width / totalFrames).round();
      final frameHeight = image.height;

      return LoadedAnimation(
        def: def,
        sheet: image,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );
    } catch (e) {
      print('Error cargando animación "${def.name}": $e');
      return null;
    }
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
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
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
    final isDoorOpen = widget.currentLevel['isDoorOpen'] == true;

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

                // ── 2. TileLayers ─────────────────────────────────
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

                // ── 3. Sprites estáticos (door, key, etc.) ────────
                ...staticSprites.map((sprite) {
                  final loadedAnim = sprite.animationId.isNotEmpty
                      ? _animCache[sprite.animationId]
                      : null;

                  // Gestionando door especificamente, si la llave no está cogida está cerrada, si está cogida se muestra abierta
                  // La animación es door_animation, el primer frame es cerrada y el segundo es abierta
                  if (sprite.type == 'door' && loadedAnim != null) {
                    final doorAnimDef = widget.animationsData
                        ?.findById(sprite.animationId);
                    if (doorAnimDef != null) {
                      final frameIndex = isDoorOpen ? 1 : 0;
                      return Positioned(
                        left: sprite.x.toDouble() -
                            sprite.width.toDouble() *
                                (doorAnimDef.anchorX),
                        top: sprite.y.toDouble() -
                            sprite.height.toDouble() *
                                (doorAnimDef.anchorY),
                        child: CustomPaint(
                          painter: _SpritePainter(
                            loadedAnim: loadedAnim,
                            frame: frameIndex,
                            flipX: sprite.flipX,
                            flipY: sprite.flipY,
                          ),
                          size: Size(sprite.width.toDouble(),
                              sprite.height.toDouble()),
                        ),
                      );
                    }
                  }

                  return Positioned(
                    left: sprite.x.toDouble() -
                        sprite.width.toDouble() *
                            (loadedAnim?.def.anchorX ?? 0.5),
                    top: sprite.y.toDouble() -
                        sprite.height.toDouble() *
                            (loadedAnim?.def.anchorY ?? 0.5),
                    child: loadedAnim != null
                        ? _AnimatedSprite(
                            loadedAnim: loadedAnim,
                            displayWidth: sprite.width.toDouble(),
                            displayHeight: sprite.height.toDouble(),
                            flipX: sprite.flipX,
                            flipY: sprite.flipY,
                          )
                        : _buildStaticSprite(
                            'assets/${sprite.imageFile}',
                            sprite.width.toDouble(),
                            sprite.height.toDouble(),
                          ),
                  );
                }),

                // ── 4. Clientes dinámicos del WebSocket ───────────
                ...widget.clients.map((client) {
                  // Verificamos si el jugador ya completó el nivel
                  final hasCompleted = client['hasCompletedLevel'] == true;

                  // Si lo ha completado, devolvemos un widget vacío para que no se renderice
                  if (hasCompleted) {
                    return const SizedBox.shrink();
                  }

                  final pixelX = (client['x'] as num).toDouble();
                  final pixelY = (client['y'] as num).toDouble() - (quixoteSprite?.height.toDouble() ?? 32) / 2;
                  final spriteW = (quixoteSprite?.width ?? 32).toDouble();
                  final spriteH = (quixoteSprite?.height ?? 32).toDouble();
                  final hasKey = client['hasKey'] == true;
                  
                  // ... resto de tu lógica de movimiento y animación ...
                  final isMovingLeft = client['isMovingLeft'] == true;
                  final isMovingRight = client['isMovingRight'] == true;
                  final isMoving = isMovingLeft || isMovingRight;
                  final movingLeft = isMovingLeft;

                  final animId = isMoving
                      ? 'anim_1776702668697288' // quixote_walk
                      : 'anim_1776702618726446'; // quixote_idle

                  final quixoteAnimDef = widget.animationsData?.findById(animId);
                  final anchorX = quixoteAnimDef?.anchorX ?? 0.5;
                  final anchorY = quixoteAnimDef?.anchorY ?? 0.5;

                  return Positioned(
                    left: pixelX - spriteW * anchorX,
                    top: pixelY - spriteH * anchorY,
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
                            _AnimatedSpriteById(
                              animationsData: widget.animationsData,
                              idleAnimId: 'anim_1776702618726446',
                              walkAnimId: 'anim_1776702668697288',
                              isMoving: isMoving,
                              flipX: movingLeft,
                              displayWidth: spriteW,
                              displayHeight: spriteH,
                            ),
                            if (hasKey && keySprite != null)
                              Positioned(
                                top: -keySprite.height.toDouble(),
                                child: _buildStaticSpriteOrAnim(
                                  keySprite,
                                  keySprite.width.toDouble(),
                                  keySprite.height.toDouble(),
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

  Widget _buildStaticSpriteOrAnim(
      Sprite sprite, double width, double height) {
    final loadedAnim = sprite.animationId.isNotEmpty
        ? _animCache[sprite.animationId]
        : null;
    if (loadedAnim != null) {
      return _AnimatedSprite(
        loadedAnim: loadedAnim,
        displayWidth: width,
        displayHeight: height,
        flipX: sprite.flipX,
        flipY: sprite.flipY,
      );
    }
    return _buildStaticSprite('assets/${sprite.imageFile}', width, height);
  }
}

// ── Widget de sprite animado (LoadedAnimation ya disponible) ──
class _AnimatedSprite extends StatefulWidget {
  final LoadedAnimation loadedAnim;
  final double displayWidth;
  final double displayHeight;
  final bool flipX;
  final bool flipY;

  const _AnimatedSprite({
    required this.loadedAnim,
    required this.displayWidth,
    required this.displayHeight,
    this.flipX = false,
    this.flipY = false,
  });

  @override
  State<_AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<_AnimatedSprite>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    final def = widget.loadedAnim.def;
    final frameCount = def.frameCount;

    if (frameCount <= 1) {
      _currentFrame = 0;
      return;
    }

    final frameDuration =
        Duration(milliseconds: (1000 / def.fps).round());
    _ctrl = AnimationController(
      vsync: this,
      duration: frameDuration * frameCount,
    );

    _ctrl.addListener(() {
      final frame =
          (_ctrl.value * frameCount).floor().clamp(0, frameCount - 1);
      if (frame != _currentFrame) {
        setState(() => _currentFrame = frame);
      }
    });

    if (def.loop) {
      _ctrl.repeat();
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    if (widget.loadedAnim.def.frameCount > 1) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpritePainter(
        loadedAnim: widget.loadedAnim,
        frame: _currentFrame,
        flipX: widget.flipX,
        flipY: widget.flipY,
      ),
      size: Size(widget.displayWidth, widget.displayHeight),
    );
  }
}

// ── Widget que carga la animación por ID y la reproduce ───
/// Usado para los jugadores dinámicos (quixote idle / walk).
class _AnimatedSpriteById extends StatefulWidget {
  final AnimationsData? animationsData;
  final String idleAnimId;
  final String walkAnimId;
  final bool isMoving;
  final bool flipX;
  final double displayWidth;
  final double displayHeight;

  const _AnimatedSpriteById({
    required this.animationsData,
    required this.idleAnimId,
    required this.walkAnimId,
    required this.isMoving,
    required this.flipX,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  State<_AnimatedSpriteById> createState() => _AnimatedSpriteByIdState();
}

class _AnimatedSpriteByIdState extends State<_AnimatedSpriteById>
    with SingleTickerProviderStateMixin {
  LoadedAnimation? _idleAnim;
  LoadedAnimation? _walkAnim;
  bool _loading = true;

  AnimationController? _ctrl;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _loadAnims();
  }

  @override
  void didUpdateWidget(_AnimatedSpriteById oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMoving != widget.isMoving) {
      _restartController();
    }
  }

  Future<void> _loadAnims() async {
    if (widget.animationsData == null) {
      setState(() => _loading = false);
      return;
    }

    final idleDef =
        widget.animationsData!.findById(widget.idleAnimId);
    final walkDef =
        widget.animationsData!.findById(widget.walkAnimId);

    if (idleDef != null) {
      _idleAnim = await _loadAnim(idleDef);
    }
    if (walkDef != null) {
      _walkAnim = await _loadAnim(walkDef);
    }

    if (mounted) {
      setState(() => _loading = false);
      _restartController();
    }
  }

  Future<LoadedAnimation?> _loadAnim(AnimationDef def) async {
    try {
      final ByteData data =
          await rootBundle.load('assets/${def.mediaFile}');
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final totalFrames = def.endFrame + 1;
      final frameWidth = (image.width / totalFrames).round();
      final frameHeight = image.height;
      return LoadedAnimation(
        def: def,
        sheet: image,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
      );
    } catch (e) {
      print('Error cargando anim ${def.name}: $e');
      return null;
    }
  }

  void _restartController() {
    _ctrl?.dispose();
    _ctrl = null;
    _currentFrame = 0;

    final activeAnim = widget.isMoving ? _walkAnim : _idleAnim;
    if (activeAnim == null) return;
    final def = activeAnim.def;
    if (def.frameCount <= 1) return;

    final frameDuration =
        Duration(milliseconds: (1000 / def.fps).round());
    _ctrl = AnimationController(
      vsync: this,
      duration: frameDuration * def.frameCount,
    );
    _ctrl!.addListener(() {
      final fc = def.frameCount;
      final frame = (_ctrl!.value * fc).floor().clamp(0, fc - 1);
      if (frame != _currentFrame && mounted) {
        setState(() => _currentFrame = frame);
      }
    });
    if (def.loop) {
      _ctrl!.repeat();
    } else {
      _ctrl!.forward();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.displayWidth,
        height: widget.displayHeight,
        child: Container(color: Colors.blue[400]),
      );
    }

    final activeAnim = widget.isMoving ? _walkAnim : _idleAnim;
    if (activeAnim == null) {
      return SizedBox(
        width: widget.displayWidth,
        height: widget.displayHeight,
        child: Container(
          color: Colors.blue[400],
          child: const Icon(Icons.person, color: Colors.white),
        ),
      );
    }

    return CustomPaint(
      painter: _SpritePainter(
        loadedAnim: activeAnim,
        frame: _currentFrame,
        flipX: widget.flipX,
        flipY: false,
      ),
      size: Size(widget.displayWidth, widget.displayHeight),
    );
  }
}

// ── CustomPainter que dibuja un frame del spritesheet ─────
class _SpritePainter extends CustomPainter {
  final LoadedAnimation loadedAnim;
  final int frame;
  final bool flipX;
  final bool flipY;

  const _SpritePainter({
    required this.loadedAnim,
    required this.frame,
    this.flipX = false,
    this.flipY = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = loadedAnim.srcRect(frame);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.none;

    if (flipX || flipY) {
      canvas.save();
      canvas.translate(
        flipX ? size.width : 0,
        flipY ? size.height : 0,
      );
      canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    }

    canvas.drawImageRect(loadedAnim.sheet, src, dst, paint);

    if (flipX || flipY) canvas.restore();
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frame != frame ||
      old.loadedAnim != loadedAnim ||
      old.flipX != flipX ||
      old.flipY != flipY;
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
      canvas.drawLine(Offset(i * cellWidth, 0),
          Offset(i * cellWidth, size.height), paint);
      canvas.drawLine(Offset(0, i * cellHeight),
          Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}