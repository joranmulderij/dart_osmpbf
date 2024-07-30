// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dart_osmpbf/dart_osmpbf.dart';

void main(List<String> arguments) {
  final file = File('./test.osm.pbf');
  final data = file.readAsBytesSync();
  final osmData = OsmData.fromBytes(data);
  print('Nodes: ${osmData.nodes.length}');
  print('Ways: ${osmData.ways.length}');
  print('Relations: ${osmData.relations.length}');
}
