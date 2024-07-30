
# dart_osmpbf

A parser for the OpenStreetMap PBF format.

Example usage:

```dart
final file = File('./test.osm.pbf');
var data = file.readAsBytesSync();
final osmData = OsmData.fromBytes(data);

print('Nodes: ${osmData.nodes.length}');
print('Ways: ${osmData.ways.length}');
print('Relations: ${osmData.relations.length}');
```
