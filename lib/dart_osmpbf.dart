import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_osmpbf/proto/fileformat.pb.dart';
import 'package:dart_osmpbf/proto/osmformat.pb.dart';

OsmData _parseOsmData(Uint8List data_) {
  var data = data_;
  HeaderBlock? headerBlock;
  var iter = 0;

  final nodes = <OsmNode>[];
  final ways = <OsmWay>[];
  final relations = <OsmRelation>[];

  while (data.isNotEmpty && iter++ < 500) {
    final blobHeaderLength = ByteData.sublistView(data, 0, 4).getUint32(0);
    data = data.sublist(4);
    final blobHeaderData = data.sublist(0, blobHeaderLength);
    data = data.sublist(blobHeaderLength);
    final blobHeader = BlobHeader.fromBuffer(blobHeaderData);
    final blobLength = blobHeader.datasize;

    final blobData = data.sublist(0, blobLength);
    data = data.sublist(blobLength);
    final blob = Blob.fromBuffer(blobData);
    final blobOutput = ZLibDecoder().convert(blob.zlibData);
    assert(blobOutput.length == blob.rawSize);
    if (blobHeader.type == 'OSMHeader') {
      headerBlock = HeaderBlock.fromBuffer(blobOutput);
    } else if (blobHeader.type == 'OSMData') {
      assert(headerBlock != null);
      final block = PrimitiveBlock.fromBuffer(blobOutput);
      final stringTable =
          block.stringtable.s.map((s) => utf8.decode(s)).toList();
      final latOffset = block.latOffset.toInt();
      final lonOffset = block.lonOffset.toInt();
      final granularity = block.granularity;
      final primitiveGroups = block.primitivegroup;
      for (final primitiveGroup in primitiveGroups) {
        if (primitiveGroup.changesets.isNotEmpty) {
          throw Exception('Changesets not supported');
        }
        if (primitiveGroup.nodes.isNotEmpty) {
          for (final node in primitiveGroup.nodes) {
            final id = node.id.toInt();
            final lat = 1e-9 * (latOffset + granularity * node.lat.toInt());
            final lon = 1e-9 * (lonOffset + granularity * node.lon.toInt());
            final tags = _parseParallelTags(node.keys, node.vals, stringTable);
            nodes.add(OsmNode(
              id: id,
              lat: lat,
              lon: lon,
              tags: tags,
            ));
          }
        }
        if (primitiveGroup.ways.isNotEmpty) {
          for (final way in primitiveGroup.ways) {
            final id = way.id.toInt();
            final refs = way.refs.map((ref) => ref.toInt()).toList();
            final tags = _parseParallelTags(way.keys, way.vals, stringTable);
            ways.add(OsmWay(
              id: id,
              refs: refs,
              tags: tags,
            ));
          }
        }
        if (primitiveGroup.relations.isNotEmpty) {
          for (final relation in primitiveGroup.relations) {
            final id = relation.id.toInt();
            final tags =
                _parseParallelTags(relation.keys, relation.vals, stringTable);
            final members = relation.memids.map((id) => id.toInt()).toList();
            final types = relation.types.map((type) {
              return switch (type) {
                Relation_MemberType.NODE => MemberType.node,
                Relation_MemberType.WAY => MemberType.way,
                Relation_MemberType.RELATION => MemberType.relation,
                _ => throw Exception('Unknown member type: $type')
              };
            }).toList();
            relations.add(OsmRelation(
              id: id,
              tags: tags,
              members: members,
              types: types,
            ));
          }
        }
        var j = 0;
        if (primitiveGroup.dense.id.isNotEmpty) {
          final dense = primitiveGroup.dense;
          var id = 0;
          for (var i = 0; i < dense.id.length; i++) {
            id += dense.id[i].toInt();
            final lat = 1e-9 * (latOffset + granularity * dense.lat[i].toInt());
            final lon = 1e-9 * (lonOffset + granularity * dense.lon[i].toInt());
            final tags = <String, String>{};
            final keyVals = dense.keysVals;
            while (dense.keysVals[j] != 0) {
              tags[stringTable[keyVals[j]]] = stringTable[keyVals[j + 1]];
              j += 2;
            }
            j++;
            nodes.add(OsmNode(
              id: id,
              lat: lat,
              lon: lon,
              tags: tags,
            ));
          }
        }
      }
    } else {
      throw Exception('Unknown blob type: ${blobHeader.type}');
    }
  }

  final bounds = headerBlock?.bbox != null &&
          (headerBlock!.bbox.bottom != 0 ||
              headerBlock.bbox.left != 0 ||
              headerBlock.bbox.top != 0 ||
              headerBlock.bbox.right != 0)
      ? OsmBounds(
          minLat: 1e-9 * headerBlock.bbox.bottom.toInt(),
          minLon: 1e-9 * headerBlock.bbox.left.toInt(),
          maxLat: 1e-9 * headerBlock.bbox.top.toInt(),
          maxLon: 1e-9 * headerBlock.bbox.right.toInt(),
        )
      : null;

  return OsmData(
    nodes: nodes,
    ways: ways,
    relations: relations,
    bounds: bounds,
  );
}

Map<String, String> _parseParallelTags(
    List<int> keys, List<int> values, List<String> stringTable) {
  final tags = <String, String>{};
  assert(keys.length == values.length);
  for (var i = 0; i < keys.length; i++) {
    if (keys[i] == 0) {
      continue;
    }
    tags[stringTable[keys[i]]] = stringTable[values[i]];
  }
  return tags;
}

/// OSM data model
class OsmData {
  /// OsmData default constructor
  OsmData({
    required this.nodes,
    required this.ways,
    required this.relations,
    this.bounds,
  });

  /// Parse pbf data and return OsmData object
  factory OsmData.fromBytes(Uint8List data) {
    return _parseOsmData(data);
  }

  /// List of nodes
  final List<OsmNode> nodes;

  /// List of ways
  final List<OsmWay> ways;

  /// List of relations
  final List<OsmRelation> relations;

  /// Bounds (optional)
  final OsmBounds? bounds;

  @override
  String toString() {
    return 'OsmData{nodes: $nodes, ways: $ways, relations: $relations}';
  }
}

/// Bounds of the OSM data
class OsmBounds {
  /// OsmBounds default constructor
  OsmBounds({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  /// Minimum latitude
  final double minLat;

  /// Minimum longitude
  final double minLon;

  /// Maximum latitude
  final double maxLat;

  /// Maximum longitude
  final double maxLon;

  @override
  String toString() {
    return 'OsmBounds{minLat: $minLat, minLon: $minLon, maxLat: $maxLat, maxLon: $maxLon}';
  }
}

sealed class _OsmPrimitive {
  _OsmPrimitive({required this.id, required this.tags});

  final int id;
  final Map<String, String> tags;
}

/// OSM node
class OsmNode extends _OsmPrimitive {
  /// OsmNode default constructor
  OsmNode({
    required super.id,
    required super.tags,
    required this.lat,
    required this.lon,
  });

  /// Latitude
  final double lat;

  /// Longitude
  final double lon;

  @override
  String toString() {
    return 'OsmNode{id: $id, tags: $tags, lat: $lat, lon: $lon}';
  }
}

/// OSM way
class OsmWay extends _OsmPrimitive {
  /// OsmWay default constructor
  OsmWay({required super.id, required super.tags, required this.refs});

  /// List of node references that make up the way
  final List<int> refs;

  @override
  String toString() {
    return 'OsmWay{id: $id, tags: $tags, refs: $refs}';
  }
}

// ignore: public_member_api_docs
enum MemberType { node, way, relation }

/// OSM relation
class OsmRelation extends _OsmPrimitive {
  /// OsmRelation default constructor
  OsmRelation({
    required super.id,
    required super.tags,
    required this.members,
    required this.types,
  }) : assert(members.length == types.length);

  /// List of ids of the members that make up the relation
  /// Should be the same length as [types]
  final List<int> members;

  /// List of types of the members that make up the relation
  /// Should be the same length as [members]
  final List<MemberType> types;

  @override
  String toString() {
    return 'OsmRelation{id: $id, tags: $tags, members: $members, types: $types}';
  }
}
