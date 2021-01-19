import 'dart:math';
import 'dart:ui';

import 'package:mapsforge_flutter/src/model/dimension.dart';
import 'package:mapsforge_flutter/src/projection/mercatorprojectionimpl.dart';

import 'boundingbox.dart';
import 'mappoint.dart';

class MapViewPosition {
  double _latitude;

  double _longitude;

  final double _tileSize;

  final int zoomLevel;

  final int indoorLevel;

  final double scale;

  final Mappoint focalPoint;

  /// the latitude/longitude boundaries of the current map view.
  /// This property must be calculated if needed based on the current view
  BoundingBox boundingBox;

  // the left/upper corner of the current mapview in pixels in relation to the current lat/lon.
  Mappoint _leftUpper;

  MercatorProjectionImpl _mercatorProjection;

  MapViewPosition(this._latitude, this._longitude, this.zoomLevel, this.indoorLevel, this._tileSize)
      : scale = 1,
        focalPoint = null,
        assert(zoomLevel >= 0),
        assert(_tileSize > 0),
        assert(_latitude == null || MercatorProjectionImpl.checkLatitude(_latitude)),
        assert(_longitude == null || MercatorProjectionImpl.checkLongitude(_longitude));

  MapViewPosition.zoomIn(MapViewPosition old)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        zoomLevel = old.zoomLevel + 1,
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.zoomInAround(MapViewPosition old, double latitude, double longitude)
      : _latitude = latitude,
        _longitude = longitude,
        zoomLevel = old.zoomLevel + 1,
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.zoomOut(MapViewPosition old)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        zoomLevel = max(old.zoomLevel - 1, 0),
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.zoom(MapViewPosition old, int zoomLevel)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        this.zoomLevel = max(zoomLevel, 0),
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.indoorLevelUp(MapViewPosition old)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        zoomLevel = old.zoomLevel,
        indoorLevel = old.indoorLevel + 1,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.indoorLevelDown(MapViewPosition old)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        zoomLevel = old.zoomLevel,
        indoorLevel = old.indoorLevel - 1,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.setIndoorLevel(MapViewPosition old, int indoorLevel)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        zoomLevel = old.zoomLevel,
        this.indoorLevel = indoorLevel,
        _tileSize = old._tileSize,
        scale = 1,
        focalPoint = null;

  MapViewPosition.scale(MapViewPosition old, this.focalPoint, this.scale)
      : _latitude = old._latitude,
        _longitude = old._longitude,
        this.zoomLevel = old.zoomLevel,
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        assert(scale != null),
        assert(scale > 0);

  MapViewPosition.move(MapViewPosition old, this._latitude, this._longitude)
      : zoomLevel = old.zoomLevel,
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        _mercatorProjection = old._mercatorProjection,
        scale = old.scale,
        focalPoint = old.focalPoint,
        assert(_latitude == null || MercatorProjectionImpl.checkLatitude(_latitude)),
        assert(_longitude == null || MercatorProjectionImpl.checkLongitude(_longitude));

  MapViewPosition.setLeftUpper(MapViewPosition old, double left, double upper, Dimension viewDimension)
      : zoomLevel = old.zoomLevel,
        indoorLevel = old.indoorLevel,
        _tileSize = old._tileSize,
        scale = old.scale,
        focalPoint = old.focalPoint,
        _mercatorProjection = old._mercatorProjection {
    //calculateBoundingBox(tileSize, viewSize);
    _leftUpper = Mappoint(min(max(left, -viewDimension.width / 2), mercatorProjection.mapSize - viewDimension.width / 2),
        min(max(upper, -viewDimension.height / 2), mercatorProjection.mapSize - viewDimension.height / 2));

    double rightX = _leftUpper.x + viewDimension.width;
    double bottomY = _leftUpper.y + viewDimension.height;

    boundingBox = BoundingBox(
        mercatorProjection.pixelYToLatitude(min(bottomY, mercatorProjection.mapSize)),
        mercatorProjection.pixelXToLongitude(max(_leftUpper.x, 0)),
        mercatorProjection.pixelYToLatitude(max(_leftUpper.y, 0)),
        mercatorProjection.pixelXToLongitude(min(rightX, mercatorProjection.mapSize)));

    _latitude = mercatorProjection.pixelYToLatitude(_leftUpper.y + viewDimension.height / 2);

    _longitude = mercatorProjection.pixelXToLongitude(_leftUpper.x + viewDimension.width / 2);

    MercatorProjectionImpl.checkLatitude(_latitude);

    MercatorProjectionImpl.checkLongitude(_longitude);
  }

  void sizeChanged() {
    _leftUpper = null;
    boundingBox = null;
  }

  bool hasPosition() {
    return _latitude != null && _longitude != null;
  }

  BoundingBox calculateBoundingBox(Dimension viewDimension) {
    if (boundingBox != null) return boundingBox;

    double centerY = mercatorProjection.latitudeToPixelY(_latitude);
    double centerX = mercatorProjection.longitudeToPixelX(_longitude);
    double leftX = centerX - viewDimension.width / 2;
    double rightX = centerX + viewDimension.width / 2;
    double topY = centerY - viewDimension.height / 2;
    double bottomY = centerY + viewDimension.height / 2;
    boundingBox = BoundingBox(
        mercatorProjection.pixelYToLatitude(min(bottomY, mercatorProjection.mapSize)),
        mercatorProjection.pixelXToLongitude(max(leftX, 0)),
        mercatorProjection.pixelYToLatitude(max(topY, 0)),
        mercatorProjection.pixelXToLongitude(min(rightX, mercatorProjection.mapSize)));
    _leftUpper = Mappoint(leftX, topY);
    return boundingBox;
  }

  Mappoint get leftUpper => _leftUpper;

  MercatorProjectionImpl get mercatorProjection {
    if (_mercatorProjection != null) return _mercatorProjection;
    _mercatorProjection = MercatorProjectionImpl(_tileSize, zoomLevel);
    return _mercatorProjection;
  }

  double get latitude => _latitude;

  double get longitude => _longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapViewPosition &&
          runtimeType == other.runtimeType &&
          _latitude == other._latitude &&
          _longitude == other._longitude &&
          zoomLevel == other.zoomLevel &&
          indoorLevel == other.indoorLevel &&
          scale == other.scale;

  @override
  int get hashCode => _latitude.hashCode ^ _longitude.hashCode ^ zoomLevel.hashCode ^ indoorLevel.hashCode << 5 ^ scale.hashCode;

  @override
  String toString() {
    return 'MapViewPosition{_latitude: $_latitude, _longitude: $_longitude, _tileSize: $_tileSize, zoomLevel: $zoomLevel, indoorLevel: $indoorLevel, scale: $scale, boundingBox: $boundingBox, _leftUpper: $_leftUpper}';
  }
}
