import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mapsforge_flutter/core.dart';
import 'package:mapsforge_flutter/datastore.dart';
import 'package:mapsforge_flutter/maps.dart';

import 'package:mapsforge_flutter/src/layer/job/jobqueue.dart';
import 'package:mapsforge_flutter/src/model/tile.dart';
import 'package:mapsforge_flutter/src/utils/layerutil.dart';
import 'package:path_provider/path_provider.dart';


import 'package:rxdart/rxdart.dart';

import 'level-bar.dart';
import 'level-detector.dart';
import 'map-file-data.dart';


class MapPageView extends StatefulWidget {
  final MapFileData mapFileData;

  const MapPageView ({
    Key key,
    @required this.mapFileData
  }) : super(key: key);

  @override
  MapPageViewState createState() => MapPageViewState();
}

class MapPageViewState extends State<MapPageView> with SingleTickerProviderStateMixin {
  final BehaviorSubject<int> indoorLevelSubject = new BehaviorSubject<int>.seeded(0);

  double downloadProgress;

  BoundingBox mapBoundingBox;

  MapModel mapModel;

  ViewModel viewModel;

  LevelDetector levelDetector;

  AnimationController fadeAnimationController;
  CurvedAnimation fadeAnimation;

  final double toolbarSpacing = 15;

  @override
  void dispose () {
    fadeAnimationController?.dispose();
    super.dispose();
  }

  @override
  void initState () {
    _prepare();

    fadeAnimationController = AnimationController(
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 300),
        value: 0,
        vsync: this,
        lowerBound: 0,
        upperBound: 1
    );
    fadeAnimation = CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.ease
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (this.mapModel == null || this.downloadProgress != 1) {
      return Scaffold(
        appBar:AppBar(
          title: Text(widget.mapFileData.name),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(
              value: downloadProgress == null || downloadProgress == 1 ? null : downloadProgress,
            ),
            SizedBox(
              height: 20,
            ),
            Center(
              child: Text(downloadProgress == null || downloadProgress == 1 ? "Loading" : "Downloading ${(downloadProgress*100).round()}%")
            ),
          ],
        )
      );
    }

    return Scaffold(
      appBar: _buildHead(context),
      body: _buildBody(context),
    );
  }

  Widget _buildHead(BuildContext context) {
    return AppBar(
      title: Text(widget.mapFileData.name),
      actions: <Widget>[
        PopupMenuButton<String>(
          onSelected: (choice) => _handleMenuItemSelect(choice, context),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: "start_location",
              child: Text("Back to Start"),
            ),
            PopupMenuItem<String>(
              value: "performance_test",
              child: Text("Start Performance Test"),
            ),
            PopupMenuItem<String>(
              enabled: false,
              value: "current_zoom_level",
              child:  Text("Zoom level: ${this.viewModel.mapViewPosition.zoomLevel}")
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          FlutterMapView(
              mapModel: mapModel,
              viewModel: viewModel,
          ),
          Positioned(
              bottom: toolbarSpacing,
              right: toolbarSpacing,
              top: toolbarSpacing,
              // this widget has an unbound width
              // left: toolbarSpacing,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: Visibility(
                      visible: !fadeAnimationController.isDismissed,
                      child: FadeTransition(
                        opacity: fadeAnimationController,
                        child: IndoorLevelBar(
                          indoorLevelSubject: indoorLevelSubject,
                          indoorLevels: levelDetector.levelMappings.value,
                          //{ 5:null, 4:null,3:null, 2: "OG2", 1: "OG1", 0: "EG", -1: "UG1", -2: null, -3: null, -4: null, -5: null },
                          width: 45,
                          fillColor: Colors.white,
                          elevation: 2.0,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        )
                      ),
                    ),
                  ),
                  SizedBox (
                      height: toolbarSpacing
                  ),
                  RawMaterialButton(
                    onPressed: () {
                      viewModel.zoomIn();
                    },
                    elevation: 2.0,
                    fillColor: Colors.white,
                    child: Icon(
                        Icons.add
                    ),
                    padding: EdgeInsets.all(10.0),
                    shape: CircleBorder(),
                    constraints: BoxConstraints(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  SizedBox (
                    height: toolbarSpacing
                  ),
                  RawMaterialButton(
                    onPressed: () {
                      viewModel.zoomOut();
                    },
                    elevation: 2.0,
                    fillColor: Colors.white,
                    child: Icon(
                        Icons.remove
                    ),
                    padding: EdgeInsets.all(10.0),
                    shape: CircleBorder(),
                    constraints: BoxConstraints(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]
              )
            )
        ]
    );
  }

  Future<void> _prepare () async {
    String filePath = await widget.mapFileData.getLocalFilePath();

    if (await widget.mapFileData.fileExists()) {
      downloadProgress = 1;
    }
    else {
      Dio dio = Dio();
      try {
        Response response = await dio.download(
          widget.mapFileData.url,
          filePath,
          onReceiveProgress: (int received, int total) {
            // file size not determined
            if (total == -1) return downloadProgress = 1;
            setState(() {
              downloadProgress = received / total;
            });
          },
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
          ),
        );
      }
      catch (e) {
        print("Download Error - $e");
      }
    }

    final MapFile mapFile = MapFile(filePath, null, null);
    await mapFile.init();
    //mapFile.debug();
    final MapDataStore mapDataStore = mapFile;
    final SymbolCache symbolCache = FileSymbolCache(rootBundle);
    final GraphicFactory graphicFactory = FlutterGraphicFactory(symbolCache);
    final DisplayModel displayModel = DisplayModel();
    final RenderThemeBuilder renderThemeBuilder = RenderThemeBuilder(graphicFactory, displayModel);
    final String content = await rootBundle.loadString("assets/custom.xml");
    renderThemeBuilder.parseXml(content);
    final RenderTheme renderTheme = renderThemeBuilder.build();
    final JobRenderer jobRenderer = MapDataStoreRenderer(mapDataStore, renderTheme, graphicFactory, true);
    final FileTileBitmapCache bitmapCache = FileTileBitmapCache(jobRenderer.getRenderKey());

    mapBoundingBox = mapFile.boundingBox;

    mapModel = MapModel(
      displayModel: displayModel,
      graphicsFactory: graphicFactory,
      renderer: jobRenderer,
      tileBitmapCache: bitmapCache,
    );

    viewModel = ViewModel(displayModel: mapModel.displayModel);

    // set default position
    viewModel.setMapViewPosition(widget.mapFileData.initialPositionLat, widget.mapFileData.initialPositionLong);
    viewModel.setZoomLevel(widget.mapFileData.initialZoomLevel);

    levelDetector = new LevelDetector(viewModel, mapDataStore);

    levelDetector.levelMappings.listen((levelMappings) {
      if (levelMappings.length > 1) {
        if (fadeAnimationController.isDismissed || fadeAnimationController.status == AnimationStatus.reverse) {
          // fade in level bar
          fadeAnimationController.forward();
        }
        // update level mappings and show level bar
        setState(() {});
      }
      else {
        if (fadeAnimationController.isCompleted  || fadeAnimationController.status == AnimationStatus.forward) {
          // fade out and hide level bar
          fadeAnimationController.reverse().whenComplete(() => setState(() {}));
        }
      }
    });

    // attach indoor level stream to indoor change function
    indoorLevelSubject.listen(viewModel.setIndoorLevel);

    setState(() {});
  }


  void _handleMenuItemSelect (String value, BuildContext context) {
    switch (value) {
      case 'start_location':
        this.viewModel.setMapViewPosition(widget.mapFileData.initialPositionLat, widget.mapFileData.initialPositionLong);
        this.viewModel.setZoomLevel(widget.mapFileData.initialZoomLevel);
        break;

      case 'performance_test':
        final zoomLevelSequence = [14,16,18,20];

        // always use same seed so sequence is determined
        final random = new Random(1);

        // clear all previous performance measurements
        performance.clear();

        int stepsPerZoomLevel = 50;

        Timer.periodic(Duration(seconds: 2), (timer) async {
          // exit performance test if all rounds are finished
          if (timer.tick > stepsPerZoomLevel * zoomLevelSequence.length) {
            // stop timer
            timer.cancel();

            var path;
            // write performance measurements to file
            if (Platform.isAndroid) {
              path = await getExternalStorageDirectory();
            }
            else {
              path = await getApplicationDocumentsDirectory();
            }
            final file = await File('${path.path}/performance_measurements-${widget.mapFileData.name}-${DateTime.now().toString()}.json').create(recursive: true);
            file.writeAsString(performance.toString());
            // show dialog with path to file
            showDialog(context: context, builder: (_) => AlertDialog(
                title: Text("Log saved at:"),
                content: Text(path.path)
            ));

            return;
          }

          // clear cache every 10 steps
          if (timer.tick % 10 == 0) {
            await this.mapModel.tileBitmapCache.purgeAll();
          }

          // set next zoom level
          if ((timer.tick - 1) % stepsPerZoomLevel == 0) {
            int i = ((timer.tick - 1) / stepsPerZoomLevel).round();
            this.viewModel.setZoomLevel(zoomLevelSequence[i]);
          }

          // get and set random position between map bounding box
          double nextLatitude = random.nextDouble() * (this.mapBoundingBox.maxLatitude - this.mapBoundingBox.minLatitude) + this.mapBoundingBox.minLatitude;
          double nextLongitude = random.nextDouble() * (this.mapBoundingBox.maxLongitude - this.mapBoundingBox.minLongitude) + this.mapBoundingBox.minLongitude;
          this.viewModel.setMapViewPosition(nextLatitude, nextLongitude);
        });

        break;
    }
  }
}