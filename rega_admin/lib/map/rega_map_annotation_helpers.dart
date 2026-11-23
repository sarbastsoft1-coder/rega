import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Point regaMapPoint(LatLng p) => Point(coordinates: Position(p.longitude, p.latitude));

LineString regaMapLine(List<LatLng> pts) {
  return LineString(
    coordinates: pts.map((p) => Position(p.longitude, p.latitude)).toList(),
  );
}

int regaArgb(Color c) => c.toARGB32();

Future<void> regaClearAnnotationLayers({
  PointAnnotationManager? points,
  CircleAnnotationManager? circles,
  PolylineAnnotationManager? polylines,
}) async {
  await points?.deleteAll();
  await circles?.deleteAll();
  await polylines?.deleteAll();
}