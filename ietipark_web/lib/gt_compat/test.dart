import 'package:flutter/services.dart';
import 'dart:convert';

// ─── Models ───────────────────────────────────────────────

class GameData {
  final String name;
  final String description;
  final List<Level> levels;
  final List<Group> levelGroups;
  final List<MediaAsset> mediaAssets;
  final List<Group> mediaGroups;
  final List<ZoneType> zoneTypes;
  final String animationsFile;

  GameData({
    required this.name,
    required this.description,
    required this.levels,
    required this.levelGroups,
    required this.mediaAssets,
    required this.mediaGroups,
    required this.zoneTypes,
    required this.animationsFile,
  });

  factory GameData.fromJson(Map<String, dynamic> json) => GameData(
        name: json['name'],
        description: json['description'],
        levels: (json['levels'] as List).map((e) => Level.fromJson(e)).toList(),
        levelGroups: (json['levelGroups'] as List).map((e) => Group.fromJson(e)).toList(),
        mediaAssets: (json['mediaAssets'] as List).map((e) => MediaAsset.fromJson(e)).toList(),
        mediaGroups: (json['mediaGroups'] as List).map((e) => Group.fromJson(e)).toList(),
        zoneTypes: (json['zoneTypes'] as List).map((e) => ZoneType.fromJson(e)).toList(),
        animationsFile: json['animationsFile'],
      );
}

class Level {
  final String name;
  final String description;
  final String gameplayData;
  final List<TileLayer> layers;
  final List<Group> layerGroups;
  final List<Sprite> sprites;
  final List<Group> spriteGroups;
  final String groupId;
  final int viewportWidth;
  final int viewportHeight;
  final int viewportX;
  final int viewportY;
  final String viewportAdaptation;
  final String viewportInitialColor;
  final String viewportPreviewColor;
  final String backgroundColorHex;
  final double depthSensitivity;
  final String zonesFile;
  final String pathsFile;

  Level({
    required this.name,
    required this.description,
    required this.gameplayData,
    required this.layers,
    required this.layerGroups,
    required this.sprites,
    required this.spriteGroups,
    required this.groupId,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.viewportX,
    required this.viewportY,
    required this.viewportAdaptation,
    required this.viewportInitialColor,
    required this.viewportPreviewColor,
    required this.backgroundColorHex,
    required this.depthSensitivity,
    required this.zonesFile,
    required this.pathsFile,
  });

  factory Level.fromJson(Map<String, dynamic> json) => Level(
        name: json['name'],
        description: json['description'] ?? '',
        gameplayData: json['gameplayData'] ?? '',
        layers: (json['layers'] as List).map((e) => TileLayer.fromJson(e)).toList(),
        layerGroups: (json['layerGroups'] as List).map((e) => Group.fromJson(e)).toList(),
        sprites: (json['sprites'] as List).map((e) => Sprite.fromJson(e)).toList(),
        spriteGroups: (json['spriteGroups'] as List).map((e) => Group.fromJson(e)).toList(),
        groupId: json['groupId'],
        viewportWidth: json['viewportWidth'],
        viewportHeight: json['viewportHeight'],
        viewportX: json['viewportX'],
        viewportY: json['viewportY'],
        viewportAdaptation: json['viewportAdaptation'],
        viewportInitialColor: json['viewportInitialColor'],
        viewportPreviewColor: json['viewportPreviewColor'],
        backgroundColorHex: json['backgroundColorHex'],
        depthSensitivity: (json['depthSensitivity'] as num).toDouble(),
        zonesFile: json['zonesFile'],
        pathsFile: json['pathsFile'],
      );
}

class TileLayer {
  final String name;
  final String gameplayData;
  final int x;
  final int y;
  final double depth;
  final String tilesSheetFile;
  final int tilesWidth;
  final int tilesHeight;
  final bool visible;
  final String groupId;
  final String tileMapFile;

  TileLayer({
    required this.name,
    required this.gameplayData,
    required this.x,
    required this.y,
    required this.depth,
    required this.tilesSheetFile,
    required this.tilesWidth,
    required this.tilesHeight,
    required this.visible,
    required this.groupId,
    required this.tileMapFile,
  });

  factory TileLayer.fromJson(Map<String, dynamic> json) => TileLayer(
        name: json['name'],
        gameplayData: json['gameplayData'] ?? '',
        x: json['x'],
        y: json['y'],
        depth: (json['depth'] as num).toDouble(),
        tilesSheetFile: json['tilesSheetFile'],
        tilesWidth: json['tilesWidth'],
        tilesHeight: json['tilesHeight'],
        visible: json['visible'],
        groupId: json['groupId'],
        tileMapFile: json['tileMapFile'],
      );
}
class TileMap {
  final List<List<int>> tileMap;

  TileMap({required this.tileMap});

  factory TileMap.fromJson(Map<String, dynamic> json) => TileMap(
        tileMap: (json['tileMap'] as List)
            .map((row) => (row as List).map((cell) => cell as int).toList())
            .toList(),
      );
}

class Sprite {
  final String name;
  final String gameplayData;
  final String type;
  final String animationId;
  final int x;
  final int y;
  final int width;
  final int height;
  final String imageFile;
  final bool flipX;
  final bool flipY;
  final double depth;
  final String groupId;

  Sprite({
    required this.name,
    required this.gameplayData,
    required this.type,
    required this.animationId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.imageFile,
    required this.flipX,
    required this.flipY,
    required this.depth,
    required this.groupId,
  });

  factory Sprite.fromJson(Map<String, dynamic> json) => Sprite(
        name: json['name'],
        gameplayData: json['gameplayData'] ?? '',
        type: json['type'],
        animationId: json['animationId'],
        x: json['x'],
        y: json['y'],
        width: json['width'],
        height: json['height'],
        imageFile: json['imageFile'],
        flipX: json['flipX'],
        flipY: json['flipY'],
        depth: (json['depth'] as num).toDouble(),
        groupId: json['groupId'],
      );
}

class MediaAsset {
  final String name;
  final String fileName;
  final String mediaType;
  final int tileWidth;
  final int tileHeight;
  final String selectionColorHex;
  final String groupId;

  MediaAsset({
    required this.name,
    required this.fileName,
    required this.mediaType,
    required this.tileWidth,
    required this.tileHeight,
    required this.selectionColorHex,
    required this.groupId,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        name: json['name'],
        fileName: json['fileName'],
        mediaType: json['mediaType'],
        tileWidth: json['tileWidth'],
        tileHeight: json['tileHeight'],
        selectionColorHex: json['selectionColorHex'],
        groupId: json['groupId'],
      );
}

class ZoneType {
  final String name;
  final String color;

  ZoneType({required this.name, required this.color});

  factory ZoneType.fromJson(Map<String, dynamic> json) => ZoneType(
        name: json['name'],
        color: json['color'],
      );
}

// Reutilizable para levelGroups, layerGroups, spriteGroups, mediaGroups
class Group {
  final String id;
  final String name;
  final bool collapsed;

  Group({required this.id, required this.name, required this.collapsed});

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        collapsed: json['collapsed'],
      );
}

// ─── Loader ───────────────────────────────────────────────

Future<GameData> loadGameData() async {
  final String response =
      await rootBundle.loadString('assets/levels/game_data.json');
  final Map<String, dynamic> json = jsonDecode(response);
  return GameData.fromJson(json);
}

// ─── Uso de ejemplo ───────────────────────────────────────

void wasawasa() async {
  final gameData = await loadGameData();

  print(gameData.name);                                      // IetiPark
  print(gameData.levels.first.backgroundColorHex);           // #C4D2E3

  final sprite = gameData.levels.first.sprites.first;
  print('${sprite.name} at (${sprite.x}, ${sprite.y})');    // quixote at (0, 0)

  for (final asset in gameData.mediaAssets) {
    print('${asset.name} → ${asset.fileName}');
  }
}