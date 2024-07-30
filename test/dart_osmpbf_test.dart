import 'dart:io';

import 'package:dart_osmpbf/dart_osmpbf.dart';
import 'package:test/test.dart';

void main() {
  test('test.osm.pbf', () {
    final file = File('./test.osm.pbf');
    final data = file.readAsBytesSync();
    final osmData = OsmData.fromBytes(data);
    expect(osmData.nodes.length, 16);
    expect(osmData.ways.length, 3);
    expect(osmData.relations.length, 1);
    expect(osmData.relations.first.tags['name'], 'Ocean Features');
  });
}
