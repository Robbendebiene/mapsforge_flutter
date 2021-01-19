import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapsforge_flutter/src/graphics/tilebitmap.dart';
import 'package:mapsforge_flutter/src/implementation/graphics/fluttertilebitmap.dart';
import 'package:mapsforge_flutter/src/layer/job/job.dart';
import 'package:mapsforge_flutter/src/layer/job/jobrenderer.dart';

class DummyRenderer extends JobRenderer {
  @override
  Future<TileBitmap> executeJob(Job job) async {
    var pictureRecorder = ui.PictureRecorder();
    var canvas = ui.Canvas(pictureRecorder);
    var paint = ui.Paint();
    Random random = Random();
    paint.strokeWidth = (random.nextDouble() * 5) + 1;
    paint.color = ui.Color(0xff000000 + random.nextInt(0xffffff));
    paint.isAntiAlias = true;

    canvas.drawLine(
        ui.Offset.zero, ui.Offset(job.tile.mercatorProjection.tileSize.toDouble(), job.tile.mercatorProjection.tileSize.toDouble()), paint);
    canvas.drawLine(ui.Offset(job.tile.mercatorProjection.tileSize.toDouble(), 0),
        ui.Offset(0, job.tile.mercatorProjection.tileSize.toDouble()), paint);

    ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 10.0,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.black87))
      ..addText("${job.tile}");
    canvas.drawParagraph(
        builder.build()..layout(ui.ParagraphConstraints(width: job.tile.mercatorProjection.tileSize.toDouble())), Offset(0, 0));

    var pic = pictureRecorder.endRecording();
    ui.Image img = await pic.toImage(job.tile.mercatorProjection.tileSize.toInt(), job.tile.mercatorProjection.tileSize.toInt());
//    var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//    var buffer = byteData.buffer.asUint8List();

    FlutterTileBitmap tileBitmap = FlutterTileBitmap(img);
    return tileBitmap; //Future.value(tileBitmap);
  }

  @override
  String getRenderKey() {
    return "dummy";
  }
}
