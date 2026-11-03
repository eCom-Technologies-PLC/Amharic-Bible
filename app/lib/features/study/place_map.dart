import 'dart:math' as math;
import 'dart:typed_data';

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

/// Where Bible geography is told from: Jerusalem (Theographic's coordinates).
const _jerusalem = (lat: 31.776667, lon: 35.234167);

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
  });

  /// Water in the reading theme's info tone, land a step from the card.
  factory _MapColors.of(BuildContext context) => _MapColors(
    water: context.appColors.infoContainer,
    land: context.colors.surfaceContainerHigh,
    river: context.appColors.info,
    pin: context.colors.tertiary,
    pinEdge: context.colors.surfaceContainerLowest,
  );

  final Color water;
  final Color land;
  final Color river;
  final Color pin;
  final Color pinEdge;

  @override
  bool operator ==(Object other) =>
      other is _MapColors &&
      other.water == water &&
      other.land == land &&
      other.river == river &&
      other.pin == pin &&
      other.pinEdge == pinEdge;

  @override
  int get hashCode => Object.hash(water, land, river, pin, pinEdge);
}

typedef _LatLon = ({double lat, double lon});

/// Draws the map around [center] at [degreesPerPixel] (latitude), longitude
/// flattened by the center's latitude: water, land, rivers, lakes, then a pin
/// at [pin] or a frame around [frame]'s window on a place's map.
class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.map,
    required this.center,
    required this.degreesPerPixel,
    required this.colors,
    this.pin,
    this.frame,
  });

  final BibleLandsMap map;
  final _LatLon center;
  final double degreesPerPixel;
  final _MapColors colors;
  final _LatLon? pin;
  final _LatLon? frame;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.cos(center.lat * math.pi / 180);
    final scale = 1 / degreesPerPixel;
    Offset at(double lon, double lat) =>
        Offset(size.width / 2 + (lon - center.lon) * k * scale, size.height / 2 - (lat - center.lat) * scale);
    final halfWidth = size.width / 2 / (k * scale), halfHeight = size.height / 2 / scale;
    final view = Rect.fromLTRB(
      center.lon - halfWidth,
      center.lat - halfHeight,
      center.lon + halfWidth,
      center.lat + halfHeight,
    );

    Path path(List<MapPart> parts, {required bool closed}) {
      final p = Path()..fillType = PathFillType.evenOdd;
      for (final part in parts) {
        // A ring wholly off the map can't change what is filled on it.
        if (!_meets(part.bounds, view)) continue;
        final xy = part.points;
        final first = at(xy[0], xy[1]);
        p.moveTo(first.dx, first.dy);
        for (var i = 2; i < xy.length; i += 2) {
          final o = at(xy[i], xy[i + 1]);
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

    if (pin case final p?) {
      final o = at(p.lon, p.lat);
      canvas.drawCircle(o, _pinRadius + _pinEdge, Paint()..color = colors.pinEdge);
      canvas.drawCircle(o, _pinRadius, Paint()..color = colors.pin);
    }
    if (frame case final f?) {
      // The window of a phone-sized map of the place, at least a few pixels.
      final h = math.max(_framePixels, _phoneMapHeight * _degreesPerPixel * scale);
      final w = math.max(_framePixels, h * _aspect);
      canvas.drawRect(
        Rect.fromCenter(center: at(f.lon, f.lat), width: w, height: h),
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
      old.frame != frame;
}

/// The smallest frame drawn on the locator, in pixels.
const _framePixels = 6.0;

/// Line widths and the pin, in pixels.
const _riverWidth = 1.25;
const _frameWidth = 1.5;
const _pinRadius = 6.0;
const _pinEdge = 2.0;

/// A place's map on a phone, in pixels high (a 16:10 map in a card).
const _phoneMapHeight = 200.0;
