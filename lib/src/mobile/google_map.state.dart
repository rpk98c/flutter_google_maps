// Copyright (c) 2020, the MarchDev Toolkit project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:flinq/flinq.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_directions_api/google_directions_api.dart';

import 'utils.dart';
import '../core/utils.dart' as exception;
import '../core/google_map.dart' as gmap;
import 'package:flutter_google_maps/src/core/map_preferences.dart'
    as map_preferences;

class GoogleMapState extends gmap.GoogleMapStateBase {
  final directionsService = DirectionsService();

  final _markers = <String, Marker>{};
  final _polygons = <String, Polygon>{};
  final _polylines = <String, Polyline>{};
  final _directionMarkerCoords = <GeoCoord, dynamic>{};
  map_preferences.MapType _mapType;

  final _waitUntilReadyCompleter = Completer<Null>();

  GoogleMapController _controller;

  @override
  void initState() {
    _mapType = widget.mapType;
    super.initState();
  }

  void _setState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    } else {
      fn();
    }
  }

  Future<BitmapDescriptor> _getBmpDescFromAsset(String asset) async {
    if (asset == null) return BitmapDescriptor.defaultMarker;

    return await BitmapDescriptor.fromAssetImage(
      createLocalImageConfiguration(context),
      asset,
    );
  }

  /// Holds futures of [BitmapDescriptor] for the marker icons keyed by the
  /// url of the icon.
  Map<String, Future<BitmapDescriptor>> _markerBitmapsFutures =
      Map<String, Future<BitmapDescriptor>>();

  /// Creates a [BitmapDescriptor] from an image url, if the download fails then
  /// The futures are stored in [_markerBitmapsFutures] to prevent
  /// multiple [BitmapDescriptor] being created using the same image. If
  /// the [url] is found in [_markerBitmapsFutures] it is returned
  ///
  /// When images are donwloaded they are chanced in the default manager,
  /// this means even if the internet goes down markers will be perserved across
  /// map instantiations
  Future<BitmapDescriptor> _getBmpDescFromNetowrk(
    String url,
    int height,
  ) async {
    if (_markerBitmapsFutures[url] != null) {
      return _markerBitmapsFutures[url];
    }
    Completer<BitmapDescriptor> _completer = Completer();

    File imageAsFile = await DefaultCacheManager().getSingleFile(url);
    FileImage image = FileImage(imageAsFile);

    await image.obtainKey(ImageConfiguration()).then(
      (val) {
        ImageStreamCompleter load = image.load(
            val,
            (Uint8List bytes, {int cacheWidth, int cacheHeight}) =>
                instantiateImageCodec(
                  bytes,
                  targetHeight: height,           
                ));
        load.addListener(
          ImageStreamListener(
            (ImageInfo imageInfo, _) {
              imageInfo.image.toByteData(format: ImageByteFormat.png).then(
                (ByteData data) {
                  _completer.complete(
                    BitmapDescriptor.fromBytes(data.buffer.asUint8List()),
                  );
                },
              );
            },
            onError: (why, stack) {
              _completer.complete(
                BitmapDescriptor.defaultMarker,
              );
            },
          ),
        );
      },
    );
    _markerBitmapsFutures[url] = _completer.future;
    return _completer.future;
  }

  @override
  void moveCamera(
    GeoCoordBounds newBounds, {
    double padding = 0,
    bool animated = true,
    bool waitUntilReady = true,
  }) async {
    assert(() {
      if (newBounds == null) {
        throw ArgumentError.notNull('newBounds');
      }

      return true;
    }());

    if (waitUntilReady == true) {
      await _waitUntilReadyCompleter.future;
    }

    if (animated == true) {
      await _controller?.animateCamera(CameraUpdate.newLatLngBounds(
        newBounds.toLatLngBounds(),
        padding ?? 0,
      ));
    } else {
      await _controller?.moveCamera(CameraUpdate.newLatLngBounds(
        newBounds.toLatLngBounds(),
        padding ?? 0,
      ));
    }
  }

  @override
  void changeMapStyle(
    String mapStyle, {
    bool waitUntilReady = true,
  }) async {
    if (waitUntilReady == true) {
      await _waitUntilReadyCompleter.future;
    }
    try {
      await _controller?.setMapStyle(mapStyle);
    } on MapStyleException catch (e) {
      throw exception.MapStyleException(e.cause);
    }
  }

  @override
  void changeMapType(
    map_preferences.MapType mapType, {
    bool waitUntilReady = true,
  }) async {
    if (waitUntilReady == true) {
      await _waitUntilReadyCompleter.future;
    }
    _setState(() {
      this._mapType = mapType;
    });
  }

  @override
  void addMarker(
    GeoCoord position, {
    String label,
    String icon,
    String info,
    String infoSnippet,
    VoidCallback onTap,
    VoidCallback onInfoWindowTap,
    int height,
  }) async {
    assert(() {
      if (position == null) {
        throw ArgumentError.notNull('position');
      }

      if (position.latitude == null || position.longitude == null) {
        throw ArgumentError.notNull('position.latitude && position.longitude');
      }

      return true;
    }());

    final key = position.toString();

    if (_markers.containsKey(key)) return;

    final markerId = MarkerId(key);
    final marker = Marker(
      markerId: markerId,
      onTap: onTap,
      consumeTapEvents: onTap != null,
      position: position.toLatLng(),
      icon: icon == null
          ? BitmapDescriptor.defaultMarker
          : await _getBmpDescFromNetowrk(icon, height),
      infoWindow: info != null
          ? InfoWindow(
              title: info,
              snippet: infoSnippet,
              onTap: onInfoWindowTap,
            )
          : null,
    );

    _setState(() => _markers[key] = marker);
  }

  @override
  void removeMarker(GeoCoord position) {
    assert(() {
      if (position == null) {
        throw ArgumentError.notNull('position');
      }

      if (position.latitude == null || position.longitude == null) {
        throw ArgumentError.notNull('position.latitude && position.longitude');
      }

      return true;
    }());

    final key = position.toString();

    if (!_markers.containsKey(key)) return;

    _setState(() => _markers.remove(key));
  }

  @override
  void clearMarkers() => _setState(() => _markers.clear());

  @override
  void addDirection(
    dynamic origin,
    dynamic destination, {
    String startLabel,
    String startIcon,
    String startInfo,
    String endLabel,
    String endIcon,
    String endInfo,
  }) {
    assert(() {
      if (origin == null) {
        throw ArgumentError.notNull('origin');
      }

      if (destination == null) {
        throw ArgumentError.notNull('destination');
      }

      return true;
    }());

    final request = DirectionsRequest(
      origin: origin,
      destination: destination,
      travelMode: TravelMode.driving,
    );
    directionsService.route(
      request,
      (response, status) {
        if (status == DirectionsStatus.ok) {
          final key = '${origin}_$destination';

          if (_polylines.containsKey(key)) return;

          moveCamera(
            response?.routes?.firstOrNull?.bounds,
            padding: 80,
          );

          final leg = response?.routes?.firstOrNull?.legs?.firstOrNull;

          final startLatLng = leg?.startLocation;
          // if (startLatLng != null) {
          //   _directionMarkerCoords[startLatLng] = origin;
          //   if (startIcon != null || startInfo != null || startLabel != null) {
          //     addMarker(
          //       startLatLng,
          //       icon: startIcon ?? 'assets/images/marker_a.png',
          //       info: startInfo ?? leg.startAddress,
          //       label: startLabel,
          //     );
          //   } else {
          //     addMarker(
          //       startLatLng,
          //       icon: 'assets/images/marker_a.png',
          //       info: leg.startAddress,
          //     );
          //   }
          // }

          final endLatLng = leg?.endLocation;
          // if (endLatLng != null) {
          //   _directionMarkerCoords[endLatLng] = destination;
          //   if (endIcon != null || endInfo != null || endLabel != null) {
          //     addMarker(
          //       endLatLng,
          //       icon: endIcon ?? 'assets/images/marker_b.png',
          //       info: endInfo ?? leg.endAddress,
          //       label: endLabel,
          //     );
          //   } else {
          //     addMarker(
          //       endLatLng,
          //       icon: 'assets/images/marker_b.png',
          //       info: leg.endAddress,
          //     );
          //   }
          // }

          final polylineId = PolylineId(key);
          final polyline = Polyline(
            polylineId: polylineId,
            points: response?.routes?.firstOrNull?.overviewPath
                    ?.mapList((_) => _.toLatLng()) ??
                [startLatLng?.toLatLng(), endLatLng?.toLatLng()],
            color: const Color(0xcc2196F3),
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            width: 8,
          );

          _setState(() => _polylines[key] = polyline);
        }
      },
    );
  }

  @override
  void removeDirection(dynamic origin, dynamic destination) {
    assert(() {
      if (origin == null) {
        throw ArgumentError.notNull('origin');
      }

      if (destination == null) {
        throw ArgumentError.notNull('destination');
      }

      return true;
    }());

    var value = _polylines.remove('${origin}_$destination');
    final start = value?.points?.firstOrNull?.toGeoCoord();
    if (start != null) {
      removeMarker(start);
      _directionMarkerCoords.remove(start);
    }
    final end = value?.points?.lastOrNull?.toGeoCoord();
    if (end != null) {
      removeMarker(end);
      _directionMarkerCoords.remove(end);
    }
    value = null;
  }

  @override
  void clearDirections() {
    _setState(() => _polylines.clear());    
  }

  @override
  void addPolygon(
    String id,
    Iterable<GeoCoord> points, {
    Color strokeColor = const Color(0x000000),
    double strokeOpacity = 0.8,
    double strokeWidth = 1,
    Color fillColor = const Color(0x000000),
    double fillOpacity = 0.35,
  }) {
    assert(() {
      if (id == null) {
        throw ArgumentError.notNull('id');
      }

      if (points == null) {
        throw ArgumentError.notNull('position');
      }

      if (points.isEmpty) {
        throw ArgumentError.value(<GeoCoord>[], 'points');
      }

      if (points.length < 3) {
        throw ArgumentError('Polygon must have at least 3 coordinates');
      }

      return true;
    }());

    _polygons.putIfAbsent(
      id,
      () => Polygon(
        polygonId: PolygonId(id),
        points: points.mapList((_) => _.toLatLng()),
        strokeWidth: strokeWidth?.toInt() ?? 1,
        strokeColor: (strokeColor ?? const Color(0x000000))
            .withOpacity(strokeOpacity ?? 0.8),
        fillColor: (fillColor ?? const Color(0x000000))
            .withOpacity(fillOpacity ?? 0.35),
      ),
    );
  }

  @override
  void editPolygon(
    String id,
    Iterable<GeoCoord> points, {
    Color strokeColor = const Color(0x000000),
    double strokeOpacity = 0.8,
    double strokeWeight = 1,
    Color fillColor = const Color(0x000000),
    double fillOpacity = 0.35,
  }) {
    removePolygon(id);
    addPolygon(
      id,
      points,
      strokeColor: strokeColor,
      strokeOpacity: strokeOpacity,
      strokeWidth: strokeWeight,
      fillColor: fillColor,
      fillOpacity: fillOpacity,
    );
  }

  @override
  void removePolygon(String id) {
    assert(() {
      if (id == null) {
        throw ArgumentError.notNull('id');
      }

      return true;
    }());

    if (!_polygons.containsKey(id)) return;

    _setState(() => _polygons.remove(id));
  }

  @override
  void clearPolygons() => _setState(() => _polygons.clear());

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => IgnorePointer(
          ignoring: !widget.interactive,
          child: Container(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: GoogleMap(
              markers: Set<Marker>.of(_markers.values),
              polygons: Set<Polygon>.of(_polygons.values),
              polylines: Set<Polyline>.of(_polylines.values),
              mapType: MapType.values[_mapType.index],
              minMaxZoomPreference:
                  MinMaxZoomPreference(widget.minZoom, widget.minZoom),
              initialCameraPosition: CameraPosition(
                target: widget.initialPosition.toLatLng(),
                zoom: widget.initialZoom,
              ),
              onTap: (coords) => widget.onTap(coords?.toGeoCoord()),
              onLongPress: (coords) => widget.onTap(coords?.toGeoCoord()),
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
                _controller.setMapStyle(widget.mapStyle);

                _waitUntilReadyCompleter.complete();
              },
              padding: widget.mobilePreferences.padding,
              compassEnabled: widget.mobilePreferences.compassEnabled,
              trafficEnabled: widget.mobilePreferences.trafficEnabled,
              buildingsEnabled: widget.mobilePreferences.buildingsEnabled,
              indoorViewEnabled: widget.mobilePreferences.indoorViewEnabled,
              mapToolbarEnabled: widget.mobilePreferences.mapToolbarEnabled,
              myLocationEnabled: widget.mobilePreferences.myLocationEnabled,
              myLocationButtonEnabled:
                  widget.mobilePreferences.myLocationButtonEnabled,
              tiltGesturesEnabled: widget.mobilePreferences.tiltGesturesEnabled,
              zoomGesturesEnabled: widget.mobilePreferences.zoomGesturesEnabled,
              rotateGesturesEnabled:
                  widget.mobilePreferences.rotateGesturesEnabled,
              scrollGesturesEnabled:
                  widget.mobilePreferences.scrollGesturesEnabled,
            ),
          ),
        ),
      );

  @override
  void dispose() {
    super.dispose();

    _markers.clear();
    _polygons.clear();
    _polylines.clear();
    _directionMarkerCoords.clear();

    _controller = null;
  }
}
