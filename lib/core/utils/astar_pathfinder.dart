import 'dart:math';

import 'package:latlong2/latlong.dart';

class AStarPathfinder {
  static const Distance _distance = Distance();

  static List<LatLng> findShortestPath({
    required LatLng start,
    required LatLng goal,
    int gridSize = 28,
  }) {
    if (_distance(start, goal) < 1) {
      return [start, goal];
    }

    final bounds = _Bounds.fromPoints(start, goal, paddingRatio: 0.2);
    final stepLat = (bounds.maxLat - bounds.minLat) / gridSize;
    final stepLng = (bounds.maxLng - bounds.minLng) / gridSize;

    if (stepLat == 0 || stepLng == 0) {
      return [start, goal];
    }

    final startCell = _toCell(start, bounds, stepLat, stepLng, gridSize);
    final goalCell = _toCell(goal, bounds, stepLat, stepLng, gridSize);

    final openSet = <_Cell>{startCell};
    final cameFrom = <_Cell, _Cell>{};
    final gScore = <_Cell, double>{startCell: 0};
    final fScore = <_Cell, double>{
      startCell: _heuristic(startCell, goalCell, bounds, stepLat, stepLng),
    };

    while (openSet.isNotEmpty) {
      final current = _lowestFScore(openSet, fScore);
      if (current == goalCell) {
        return _reconstructPath(
          cameFrom,
          current,
          bounds,
          stepLat,
          stepLng,
          start,
          goal,
        );
      }

      openSet.remove(current);

      for (final neighbor in _neighbors(current, gridSize)) {
        final tentativeG =
            (gScore[current] ?? double.infinity) +
            _movementCost(current, neighbor, bounds, stepLat, stepLng);

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] =
              tentativeG +
              _heuristic(neighbor, goalCell, bounds, stepLat, stepLng);
          openSet.add(neighbor);
        }
      }
    }

    return [start, goal];
  }

  static _Cell _lowestFScore(Set<_Cell> nodes, Map<_Cell, double> fScore) {
    _Cell? best;
    var bestScore = double.infinity;
    for (final node in nodes) {
      final score = fScore[node] ?? double.infinity;
      if (score < bestScore) {
        best = node;
        bestScore = score;
      }
    }
    return best ?? nodes.first;
  }

  static Iterable<_Cell> _neighbors(_Cell cell, int gridSize) sync* {
    for (var dRow = -1; dRow <= 1; dRow++) {
      for (var dCol = -1; dCol <= 1; dCol++) {
        if (dRow == 0 && dCol == 0) continue;
        final nextRow = cell.row + dRow;
        final nextCol = cell.col + dCol;
        if (nextRow < 0 || nextCol < 0) continue;
        if (nextRow > gridSize || nextCol > gridSize) continue;
        yield _Cell(nextRow, nextCol);
      }
    }
  }

  static double _heuristic(
    _Cell a,
    _Cell b,
    _Bounds bounds,
    double stepLat,
    double stepLng,
  ) {
    final aPoint = _cellToLatLng(a, bounds, stepLat, stepLng);
    final bPoint = _cellToLatLng(b, bounds, stepLat, stepLng);
    return _distance(aPoint, bPoint);
  }

  static double _movementCost(
    _Cell from,
    _Cell to,
    _Bounds bounds,
    double stepLat,
    double stepLng,
  ) {
    final fromPoint = _cellToLatLng(from, bounds, stepLat, stepLng);
    final toPoint = _cellToLatLng(to, bounds, stepLat, stepLng);
    return _distance(fromPoint, toPoint);
  }

  static _Cell _toCell(
    LatLng point,
    _Bounds bounds,
    double stepLat,
    double stepLng,
    int gridSize,
  ) {
    final row = ((point.latitude - bounds.minLat) / stepLat)
        .round()
        .clamp(0, gridSize);
    final col = ((point.longitude - bounds.minLng) / stepLng)
        .round()
        .clamp(0, gridSize);
    return _Cell(row, col);
  }

  static LatLng _cellToLatLng(
    _Cell cell,
    _Bounds bounds,
    double stepLat,
    double stepLng,
  ) {
    return LatLng(
      bounds.minLat + (cell.row * stepLat),
      bounds.minLng + (cell.col * stepLng),
    );
  }

  static List<LatLng> _reconstructPath(
    Map<_Cell, _Cell> cameFrom,
    _Cell current,
    _Bounds bounds,
    double stepLat,
    double stepLng,
    LatLng start,
    LatLng goal,
  ) {
    final cellsPath = <_Cell>[current];

    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      cellsPath.add(current);
    }

    final path = cellsPath.reversed
        .map((cell) => _cellToLatLng(cell, bounds, stepLat, stepLng))
        .toList();

    if (path.isEmpty) return [start, goal];

    path[0] = start;
    path[path.length - 1] = goal;
    return path;
  }
}

class _Bounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const _Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory _Bounds.fromPoints(
    LatLng a,
    LatLng b, {
    required double paddingRatio,
  }) {
    final baseMinLat = min(a.latitude, b.latitude);
    final baseMaxLat = max(a.latitude, b.latitude);
    final baseMinLng = min(a.longitude, b.longitude);
    final baseMaxLng = max(a.longitude, b.longitude);

    final latSpan = (baseMaxLat - baseMinLat).abs();
    final lngSpan = (baseMaxLng - baseMinLng).abs();

    final latPadding = max(latSpan * paddingRatio, 0.002);
    final lngPadding = max(lngSpan * paddingRatio, 0.002);

    return _Bounds(
      minLat: baseMinLat - latPadding,
      maxLat: baseMaxLat + latPadding,
      minLng: baseMinLng - lngPadding,
      maxLng: baseMaxLng + lngPadding,
    );
  }
}

class _Cell {
  final int row;
  final int col;

  const _Cell(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _Cell && other.row == row && other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);
}
