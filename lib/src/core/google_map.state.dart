// Copyright (c) 2020, the MarchDev Toolkit project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:flutter/widgets.dart';

import 'google_map.dart';

class GoogleMapState extends GoogleMapStateBase {
  @override
  void addDirection(
    origin,
    destination, {
    String startLabel,
    String startIcon,
    String startInfo,
    String endLabel,
    String endIcon,
    String endInfo,
  }) =>
      throw UnimplementedError();

  @override
  void addMarker(
    Point<double> position, {
    String label,
    String icon,
    String info,
  }) =>
      throw UnimplementedError();

  @override
  void addPolygon(
    String id,
    Iterable<Point<double>> points, {
    Color strokeColor = const Color(0x000000),
    double strokeOpacity = 0.8,
    double strokeWidth = 1,
    Color fillColor = const Color(0x000000),
    double fillOpacity = 0.35,
  }) =>
      throw UnimplementedError();

  @override
  void clearDirections() => throw UnimplementedError();

  @override
  void clearMarkers() => throw UnimplementedError();

  @override
  void clearPolygons() => throw UnimplementedError();

  @override
  void editPolygon(
    String id,
    Iterable<Point<double>> points, {
    Color strokeColor = const Color(0x000000),
    double strokeOpacity = 0.8,
    double strokeWeight = 1,
    Color fillColor = const Color(0x000000),
    double fillOpacity = 0.35,
  }) =>
      throw UnimplementedError();

  @override
  void removeDirection(origin, destination) => throw UnimplementedError();

  @override
  void removeMarker(Point<double> position) => throw UnimplementedError();

  @override
  void removePolygon(String id) => throw UnimplementedError();

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
