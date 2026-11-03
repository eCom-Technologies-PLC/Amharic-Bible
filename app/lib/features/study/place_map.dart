import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../ui/ui.dart';

/// The map of Bible lands: land, lakes and rivers from Natural Earth (public
/// domain), simplified to about a kilometre by `pipeline/build_map.py`, which
/// describes the file. It works without a connection.
class BibleLandsMap {
  BibleLandsMap._(this.region, this.land, this.lakes, this.rivers);

  /// What the map covers: longitude west to east, latitude south to north.
  final Rect region;

  /// Rings filled even-odd (so the Caspian Sea, a hole in the land, is water).
  final List<MapPart> land;
  final List<MapPart> lakes;
  final List<MapPart> rivers;

  /// Whether [lat], [lon] is on the map (edges included).
  bool covers(double lat, double lon) =>
      lon >= region.left && lon <= region.right && lat >= region.top && lat <= region.bottom;

  /// Whether [lat], [lon] is on land, lakes included (they lie within it).
  bool onLand(double lat, double lon) {
    var inside = false;
    for (final part in land) {
      final b = part.bounds;
      // A ring around the point has the point inside its box.
      if (lon < b.left || lon > b.right || lat < b.top || lat > b.bottom) continue;
      final p = part.points;
      final n = p.length ~/ 2;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final (xi, yi, xj, yj) = (p[i * 2], p[i * 2 + 1], p[j * 2], p[j * 2 + 1]);
        if ((yi > lat) != (yj > lat) && lon < xi + (lat - yi) * (xj - xi) / (yj - yi)) inside = !inside;
      }
    }
    return inside;
  }

  static const _units = 100;

  factory BibleLandsMap.decode(ByteData data) {
    const magic = 'BLM1';
    if (data.lengthInBytes < 12 || String.fromCharCodes(Uint8List.sublistView(data, 0, 4)) != magic) {
      throw const FormatException('not a map of Bible lands');
    }
    double edge(int i) => data.getInt16(4 + i * 2, Endian.little) / _units;
    final west = edge(0), south = edge(1), east = edge(2), north = edge(3);
    var pos = 12;
    int varint() {
      var n = 0, shift = 0;
      while (true) {
        final b = data.getUint8(pos++);
        n |= (b & 0x7f) << shift;
        if (b & 0x80 == 0) return n;
        shift += 7;
      }
    }

    int signed() {
      final n = varint();
      return n.isEven ? n ~/ 2 : -(n + 1) ~/ 2;
    }

    List<MapPart> layer() {
      final parts = <MapPart>[];
      for (var count = varint(); count > 0; count--) {
        final points = Float32List(varint() * 2);
        var x = 0, y = 0;
        for (var i = 0; i < points.length; i += 2) {
          x += signed();
          y += signed();
          points[i] = west + x / _units;
          points[i + 1] = south + y / _units;
        }
        parts.add(MapPart(points));
      }
      return parts;
    }

    final land = layer(), lakes = layer(), rivers = layer();
    if (pos != data.lengthInBytes) throw const FormatException('trailing bytes in the map');
    return BibleLandsMap._(Rect.fromLTRB(west, south, east, north), land, lakes, rivers);
  }
}

/// A ring or a line: longitude, latitude pairs, with the box around them.
class MapPart {
  MapPart(this.points) : bounds = _bounds(points);

  final Float32List points;
  final Rect bounds;

  static Rect _bounds(Float32List p) {
    var (w, s, e, n) = (double.infinity, double.infinity, -double.infinity, -double.infinity);
    for (var i = 0; i < p.length; i += 2) {
      w = math.min(w, p[i]);
      e = math.max(e, p[i]);
      s = math.min(s, p[i + 1]);
      n = math.max(n, p[i + 1]);
    }
    return Rect.fromLTRB(w, s, e, n);
  }
}

final bibleLandsMapProvider = FutureProvider<BibleLandsMap>(
  (ref) async => BibleLandsMap.decode(await rootBundle.load('assets/map/bible_lands.bin')),
);

typedef LatLon = ({double lat, double lon});

/// A window on the map: [center] in the middle of a canvas of [size], at
/// [degreesPerPixel] of latitude, with longitude flattened by the center's
/// latitude (degrees of longitude shrink away from the equator).
@immutable
class MapView {
  MapView({required this.center, required this.degreesPerPixel, required this.size})
    : _k = math.cos(center.lat * math.pi / 180);

  final LatLon center;
  final double degreesPerPixel;
  final Size size;
  final double _k;

  Offset toScreen(double lat, double lon) => Offset(
    size.width / 2 + (lon - center.lon) * _k / degreesPerPixel,
    size.height / 2 - (lat - center.lat) / degreesPerPixel,
  );

  LatLon toMap(Offset o) => (
    lat: center.lat - (o.dy - size.height / 2) * degreesPerPixel,
    lon: center.lon + (o.dx - size.width / 2) * degreesPerPixel / _k,
  );

  /// What the window shows: longitude west to east, latitude south to north.
  Rect get bounds {
    final (nw, se) = (toMap(Offset.zero), toMap(Offset(size.width, size.height)));
    return Rect.fromLTRB(nw.lon, se.lat, se.lon, nw.lat);
  }
}

/// Where Bible geography is told from: Jerusalem (Theographic's coordinates).
const LatLon _jerusalem = (lat: 31.776667, lon: 35.234167);

/// How far and which way a place lies from Jerusalem: kilometres rounded as a
/// person would say them, and one of eight compass points (0 north, 1
/// north-east, … 7 north-west). Null within 2 km, where it says nothing.
({int km, int direction})? fromJerusalem(double lat, double lon) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final (p1, p2) = (rad(_jerusalem.lat), rad(lat));
  final dp = p2 - p1, dl = rad(lon - _jerusalem.lon);
  final a = math.pow(math.sin(dp / 2), 2) + math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
  final km = 2 * r * math.asin(math.sqrt(a));
  if (km < 2) return null;
  final bearing = math.atan2(
    math.sin(dl) * math.cos(p2),
    math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl),
  );
  final degrees = (bearing * 180 / math.pi + 360) % 360;
  final step = km < 20 ? 1 : (km < 100 ? 5 : (km < 1000 ? 10 : 50));
  return (km: (km / step).round() * step, direction: ((degrees + 22.5) ~/ 45) % 8);
}

/// What a name on the map names: a sea (written on open water), a lake
/// (written beside it) or a town (a dot and its name).
enum MapLabelKind { sea, lake, town }

/// A name on the map and the spots it may go: a sea at the first that shows
/// it on open water (nearest the middle first), a lake or a town beside its
/// one spot.
typedef MapLabel = ({String text, MapLabelKind kind, List<LatLon> spots});

/// The names on a place's map, in the order they are placed (each only where
/// there is room): Jerusalem as a reference point, the lakes, then the seas.
List<MapLabel> mapLabels(S s) => [
  (text: s.mapName('jerusalem'), kind: MapLabelKind.town, spots: const [_jerusalem]),
  (text: s.mapName('galilee'), kind: MapLabelKind.lake, spots: const [(lat: 32.82, lon: 35.59)]),
  (text: s.mapName('deadSea'), kind: MapLabelKind.lake, spots: const [(lat: 31.5, lon: 35.48)]),
  (text: s.mapName('tana'), kind: MapLabelKind.lake, spots: const [(lat: 12.0, lon: 37.3)]),
  (
    text: s.mapName('mediterranean'),
    kind: MapLabelKind.sea,
    spots: const [
      (lat: 32.4, lon: 33.6),
      (lat: 33.7, lon: 34.2),
      (lat: 32.3, lon: 31.0),
      (lat: 33.8, lon: 27.5),
      (lat: 33.6, lon: 22.5),
      (lat: 35.2, lon: 19.5),
      (lat: 37.8, lon: 5.0),
    ],
  ),
  (
    text: s.mapName('redSea'),
    kind: MapLabelKind.sea,
    spots: const [
      (lat: 26.5, lon: 35.3),
      (lat: 23.5, lon: 37.0),
      (lat: 20.0, lon: 38.8),
      (lat: 16.5, lon: 40.5),
      (lat: 14.0, lon: 42.0),
    ],
  ),
  (
    text: s.mapName('aegean'),
    kind: MapLabelKind.sea,
    spots: const [(lat: 38.6, lon: 25.2), (lat: 39.8, lon: 24.6), (lat: 36.9, lon: 25.9)],
  ),
  (
    text: s.mapName('adriatic'),
    kind: MapLabelKind.sea,
    spots: const [(lat: 43.0, lon: 15.6), (lat: 41.9, lon: 17.4), (lat: 44.6, lon: 13.2)],
  ),
  (
    text: s.mapName('blackSea'),
    kind: MapLabelKind.sea,
    spots: const [(lat: 43.0, lon: 34.0), (lat: 42.5, lon: 30.0), (lat: 42.8, lon: 38.5)],
  ),
  (
    text: s.mapName('caspian'),
    kind: MapLabelKind.sea,
    spots: const [(lat: 42.0, lon: 50.5), (lat: 39.0, lon: 51.2), (lat: 44.8, lon: 50.0)],
  ),
  (
    text: s.mapName('persianGulf'),
    kind: MapLabelKind.sea,
    spots: const [(lat: 27.0, lon: 51.0), (lat: 28.8, lon: 49.8), (lat: 25.8, lon: 54.3)],
  ),
];

/// The names placed on [view], each in a box of the size [measure] gives it:
/// inside the map, clear of the pin at [pin] and of each other, and a sea's
/// box wholly on open water. A town's [dot] is where to draw it. Names
/// without room are left out.
List<({MapLabel label, Rect box, Offset? dot})> placeMapLabels({
  required BibleLandsMap map,
  required MapView view,
  required List<MapLabel> labels,
  required Size Function(MapLabel) measure,
  LatLon? pin,
}) {
  final inside = (Offset.zero & view.size).deflate(_labelMargin);
  final taken = <Rect>[
    if (pin != null)
      Rect.fromCircle(center: view.toScreen(pin.lat, pin.lon), radius: _pinRadius + _pinEdge + _labelGap),
  ];
  bool fits(Rect r) =>
      r.left >= inside.left && r.right <= inside.right && r.top >= inside.top && r.bottom <= inside.bottom;
  bool free(Rect r) => fits(r) && !taken.any(r.overlaps);
  bool onWater(Rect r) => [
    r.topLeft,
    r.topCenter,
    r.topRight,
    r.centerLeft,
    r.center,
    r.centerRight,
    r.bottomLeft,
    r.bottomCenter,
    r.bottomRight,
  ].map(view.toMap).every((p) => !map.onLand(p.lat, p.lon));
  bool onLand(Rect r) => [
    r.topLeft,
    r.topRight,
    r.center,
    r.bottomLeft,
    r.bottomRight,
  ].map(view.toMap).every((p) => map.onLand(p.lat, p.lon));

  final placed = <({MapLabel label, Rect box, Offset? dot})>[];
  for (final label in labels) {
    final size = measure(label);
    if (label.kind == MapLabelKind.sea) {
      double away(LatLon p) {
        final (dy, dx) = (p.lat - view.center.lat, p.lon - view.center.lon);
        return dx * dx + dy * dy;
      }

      for (final spot in [...label.spots]..sort((a, b) => away(a).compareTo(away(b)))) {
        final at = view.toScreen(spot.lat, spot.lon);
        if (!inside.contains(at)) continue;
        // Kept near its spot: moved at most half its size to fit the map.
        final box = _shiftedInside(Rect.fromCenter(center: at, width: size.width, height: size.height), inside);
        if (box == null || !free(box) || !onWater(box)) continue;
        taken.add(box);
        placed.add((label: label, box: box, dot: null));
        break;
      }
      continue;
    }
    final spot = label.spots.first;
    final at = view.toScreen(spot.lat, spot.lon);
    final town = label.kind == MapLabelKind.town;
    final dot = town ? Rect.fromCircle(center: at, radius: _townDot) : null;
    // A town under the pin (the place itself, or close by) goes unnamed.
    if (dot != null ? !free(dot) : !inside.contains(at)) continue;
    // Around the town's dot or the lake's shores (not over its water): to
    // the right, left, above, below, then the corners. A spot wholly on land
    // first, so the name doesn't straddle a coast; else any with room.
    final e = town ? Rect.fromCircle(center: at, radius: _townDot) : _extent(map, view, spot, at);
    final (w, h, g) = (size.width, size.height, _labelGap);
    final around = [
      Rect.fromLTWH(e.right + g, at.dy - h / 2, w, h),
      Rect.fromLTWH(e.left - g - w, at.dy - h / 2, w, h),
      Rect.fromLTWH(at.dx - w / 2, e.top - g - h, w, h),
      Rect.fromLTWH(at.dx - w / 2, e.bottom + g, w, h),
      Rect.fromLTWH(e.right + g, e.top - h, w, h),
      Rect.fromLTWH(e.right + g, e.bottom, w, h),
      Rect.fromLTWH(e.left - g - w, e.top - h, w, h),
      Rect.fromLTWH(e.left - g - w, e.bottom, w, h),
    ].where(free);
    final box = around.where(onLand).firstOrNull ?? around.firstOrNull;
    if (box == null) continue;
    taken.addAll([box, ?dot]);
    placed.add((label: label, box: box, dot: dot?.center));
  }
  return placed;
}

/// Where a lake lies on [view], on screen: the lake around [spot] (the Dead
/// Sea's northern basin, not its southern one), or a few pixels around [at]
/// when none is.
Rect _extent(BibleLandsMap map, MapView view, LatLon spot, Offset at) {
  final lake = map.lakes.where((l) => l.bounds.contains(Offset(spot.lon, spot.lat))).firstOrNull;
  if (lake == null) return Rect.fromCircle(center: at, radius: _lakeGap);
  final b = lake.bounds;
  return Rect.fromPoints(view.toScreen(b.top, b.left), view.toScreen(b.bottom, b.right));
}

/// [box] moved to lie within [area], or null when it doesn't fit.
Rect? _shiftedInside(Rect box, Rect area) {
  if (box.width > area.width || box.height > area.height) return null;
  final dx = box.left < area.left ? area.left - box.left : (box.right > area.right ? area.right - box.right : 0.0);
  final dy = box.top < area.top ? area.top - box.top : (box.bottom > area.bottom ? area.bottom - box.bottom : 0.0);
  return box.shift(Offset(dx, dy));
}

/// Latitude degrees per logical pixel on a place's map: about 2.6° from top
/// to bottom on a phone, enough to see Galilee from Jerusalem.
const _degreesPerPixel = 0.0135;

/// A place on the map of Bible lands, with where that is from Jerusalem and a
/// small map of the whole region framing it; [onOpenOnline] opens a full map
/// (it needs a connection). Places beyond the map show their coordinates.
class PlaceMapCard extends ConsumerWidget {
  const PlaceMapCard({super.key, required this.name, required this.lat, required this.lon, required this.onOpenOnline});

  final String name;
  final double lat;
  final double lon;
  final VoidCallback onOpenOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final map = ref.watch(bibleLandsMapProvider).value;
    final away = fromJerusalem(lat, lon);
    final where = away == null ? null : s.fromJerusalem(away.km, away.direction);
    final shown = map != null && map.covers(lat, lon);
    final colors = _MapColors.of(context);
    return AppCard(
      eyebrow: s.map,
      actions: [
        AppButton.outline(
          label: shown ? s.largerMap : s.showOnMap,
          icon: Icons.open_in_new,
          iconAtEnd: true,
          onPressed: onOpenOnline,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shown) ...[
            LayoutBuilder(
              builder: (context, box) {
                final height = math.min(box.maxWidth / _aspect, AppDimens.placeMapMaxHeight);
                // An image of its own for screen readers, said in words.
                return Semantics(
                  container: true,
                  image: true,
                  label: [s.mapOf(name), ?where].join('. '),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      height: height,
                      child: CustomPaint(
                        painter: _MapPainter(
                          map: map,
                          center: (lat: lat, lon: lon),
                          degreesPerPixel: _degreesPerPixel,
                          colors: colors,
                          pin: (lat: lat, lon: lon),
                          labels: mapLabels(s),
                          textScaler: MediaQuery.textScalerOf(context),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              if (shown) ...[
                ExcludeSemantics(
                  child: _Locator(map: map, lat: lat, lon: lon, colors: colors),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (where != null) Text(where, style: context.text.bodyMedium),
                    if (!shown)
                      Text(
                        '${s.coordinates}: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                        style: context.text.bodyMedium,
                      ),
                    if (shown)
                      Text(
                        s.mapCredit,
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The map's width to its height, at most [AppDimens.placeMapMaxHeight] high.
const _aspect = 1.6;

/// The whole region, small, with a frame where the place's map is.
class _Locator extends StatelessWidget {
  const _Locator({required this.map, required this.lat, required this.lon, required this.colors});

  final BibleLandsMap map;
  final double lat;
  final double lon;
  final _MapColors colors;

  @override
  Widget build(BuildContext context) {
    final region = map.region;
    final k = math.cos(region.center.dy * math.pi / 180);
    // The region's own shape, flattened as the painter flattens it.
    final aspect = region.width * k / region.height;
    const width = AppDimens.mapLocatorWidth;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: width,
        height: width / aspect,
        child: CustomPaint(
          painter: _MapPainter(
            map: map,
            center: (lat: region.center.dy, lon: region.center.dx),
            degreesPerPixel: region.height / (width / aspect),
            colors: colors,
            frame: (lat: lat, lon: lon),
          ),
        ),
      ),
    );
  }
}

@immutable
class _MapColors {
  const _MapColors({
    required this.water,
    required this.land,
    required this.river,
    required this.pin,
    required this.pinEdge,
    required this.waterName,
    required this.townName,
  });

  /// Water in the reading theme's info tone, land a step from the card; names
  /// of water in the water's own deeper tone.
  factory _MapColors.of(BuildContext context) => _MapColors(
    water: context.appColors.infoContainer,
    land: context.colors.surfaceContainerHigh,
    river: context.appColors.info,
    pin: context.colors.tertiary,
    pinEdge: context.colors.surfaceContainerLowest,
    waterName: context.text.labelSmall?.copyWith(color: context.appColors.info),
    townName: context.text.labelSmall?.copyWith(color: context.colors.onSurface),
  );

  final Color water;
  final Color land;
  final Color river;
  final Color pin;
  final Color pinEdge;
  final TextStyle? waterName;
  final TextStyle? townName;

  @override
  bool operator ==(Object other) =>
      other is _MapColors &&
      other.water == water &&
      other.land == land &&
      other.river == river &&
      other.pin == pin &&
      other.pinEdge == pinEdge &&
      other.waterName == waterName &&
      other.townName == townName;

  @override
  int get hashCode => Object.hash(water, land, river, pin, pinEdge, waterName, townName);
}

/// Draws the map around [center] at [degreesPerPixel]: water, land, rivers,
/// lakes, the [labels] that have room, then a pin at [pin] or a frame around
/// [frame]'s window on a place's map.
class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.map,
    required this.center,
    required this.degreesPerPixel,
    required this.colors,
    this.pin,
    this.frame,
    this.labels = const [],
    this.textScaler = TextScaler.noScaling,
  });

  final BibleLandsMap map;
  final LatLon center;
  final double degreesPerPixel;
  final _MapColors colors;
  final LatLon? pin;
  final LatLon? frame;
  final List<MapLabel> labels;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final view = MapView(center: center, degreesPerPixel: degreesPerPixel, size: size);
    final shown = view.bounds;

    Path path(List<MapPart> parts, {required bool closed}) {
      final p = Path()..fillType = PathFillType.evenOdd;
      for (final part in parts) {
        // A ring wholly off the map can't change what is filled on it.
        if (!_meets(part.bounds, shown)) continue;
        final xy = part.points;
        final first = view.toScreen(xy[1], xy[0]);
        p.moveTo(first.dx, first.dy);
        for (var i = 2; i < xy.length; i += 2) {
          final o = view.toScreen(xy[i + 1], xy[i]);
          p.lineTo(o.dx, o.dy);
        }
        if (closed) p.close();
      }
      return p;
    }

    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.water);
    canvas.drawPath(path(map.land, closed: true), Paint()..color = colors.land);
    canvas.drawPath(
      path(map.rivers, closed: false),
      Paint()
        ..color = colors.river
        ..style = PaintingStyle.stroke
        ..strokeWidth = _riverWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(path(map.lakes, closed: true), Paint()..color = colors.water);

    if (labels.isNotEmpty) {
      final texts = {
        for (final l in labels)
          l: TextPainter(
            text: TextSpan(text: l.text, style: l.kind == MapLabelKind.town ? colors.townName : colors.waterName),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout(),
      };
      final placed = placeMapLabels(map: map, view: view, labels: labels, measure: (l) => texts[l]!.size, pin: pin);
      for (final (:label, :box, :dot) in placed) {
        // Names on land sit on a plate of the land's color, over the rivers.
        if (label.kind != MapLabelKind.sea) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(box.inflate(_plateMargin), const Radius.circular(_plateMargin)),
            Paint()..color = colors.land.withValues(alpha: AppOpacity.plate),
          );
        }
        if (dot != null) canvas.drawCircle(dot, _townDot, Paint()..color = colors.townName?.color ?? colors.river);
        texts[label]!.paint(canvas, box.topLeft);
      }
      for (final t in texts.values) {
        t.dispose();
      }
    }

    if (pin case final p?) {
      final o = view.toScreen(p.lat, p.lon);
      canvas.drawCircle(o, _pinRadius + _pinEdge, Paint()..color = colors.pinEdge);
      canvas.drawCircle(o, _pinRadius, Paint()..color = colors.pin);
    }
    if (frame case final f?) {
      // The window of a phone-sized map of the place, at least a few pixels.
      final h = math.max(_framePixels, _phoneMapHeight * _degreesPerPixel / degreesPerPixel);
      final w = math.max(_framePixels, h * _aspect);
      canvas.drawRect(
        Rect.fromCenter(center: view.toScreen(f.lat, f.lon), width: w, height: h),
        Paint()
          ..color = colors.pin
          ..style = PaintingStyle.stroke
          ..strokeWidth = _frameWidth,
      );
    }
  }

  /// Whether two boxes share any point (edges included).
  static bool _meets(Rect a, Rect b) =>
      a.left <= b.right && b.left <= a.right && a.top <= b.bottom && b.top <= a.bottom;

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.map != map ||
      old.center != center ||
      old.degreesPerPixel != degreesPerPixel ||
      old.colors != colors ||
      old.pin != pin ||
      old.frame != frame ||
      old.textScaler != textScaler ||
      !listEquals(old.labels, labels);
}

/// The smallest frame drawn on the locator, in pixels.
const _framePixels = 6.0;

/// A place's map on a phone, in pixels high (a 16:10 map in a card).
const _phoneMapHeight = 200.0;

/// Line widths, the pin and the names, in pixels.
const _riverWidth = 1.25;
const _frameWidth = 1.5;
const _pinRadius = 6.0;
const _pinEdge = 2.0;
const _townDot = 2.5;
const _labelGap = 4.0;
const _lakeGap = 8.0;
const _labelMargin = 4.0;
const _plateMargin = 2.0;
