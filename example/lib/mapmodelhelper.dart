import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/datastore.dart';
import 'package:mapsforge_flutter/maps.dart';
import 'package:path_provider/path_provider.dart';

class MapModelHelper {
  static final _log = new Logger('MapModelHelper');

  static Future<String> findLocalPath() async {
//    final directory = widget.platform == TargetPlatform.android
//        ? await getExternalStorageDirectory()
//        : await getApplicationDocumentsDirectory();
//    return directory.path;
    String result = (await getApplicationDocumentsDirectory()).path;
    //result += '/dailyflightbuddy/maps';

    var savedDir = Directory(result);
    bool exists = await savedDir.exists();
    if (!exists) {
      print("Creating directory $result");
      savedDir.create(recursive: true);
    }

    return result;
  }

  static Future<MapModel> prepareMapModel(String? filename, double? lat, double? lon, int zoomLevel, bool online) async {
    String _localPath = await findLocalPath();

    late MapDataStore mapDataStore;
    if (online) {
      //mapDataStore = MapOnlineRenderer();
    } else {
      _log.info("opening mapfile ${_localPath + "/" + filename!}");
      MapFile mapFile = await MapFile.from(_localPath + "/" + filename, null, null);
      //await mapFile.debug();
      //mapDataStore.addMapDataStore(mapFile, false, false);
      mapDataStore = mapFile;
    }

    SymbolCache symbolCache = FileSymbolCache(rootBundle);
    GraphicFactory graphicFactory = FlutterGraphicFactory(symbolCache);
    final DisplayModel displayModel = DisplayModel();

    RenderThemeBuilder renderThemeBuilder = RenderThemeBuilder(graphicFactory, displayModel);
    String content = await rootBundle.loadString("assets/defaultrender.xml");
    renderThemeBuilder.parseXml(content);
    RenderTheme renderTheme = renderThemeBuilder.build();
    JobRenderer jobRenderer;
    if (online) {
      jobRenderer = MapOnlineRenderer();
    } else {
      jobRenderer = MapDataStoreRenderer(mapDataStore, renderTheme, graphicFactory, true);
    }
    FileTileBitmapCache bitmapCache = await FileTileBitmapCache.create(jobRenderer.getRenderKey());

    MapModel mapModel = MapModel(
      displayModel: displayModel,
      graphicsFactory: graphicFactory,
      renderer: jobRenderer,
      tileBitmapCache: bitmapCache,
    );

    // set default position
    // mapModel.setMapViewPosition(lat, lon);
    //
    // mapModel.setZoomLevel(zoomLevel);

    return mapModel;
  }
}
