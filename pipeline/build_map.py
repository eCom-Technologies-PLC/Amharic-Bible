"""The map of Bible lands drawn on a place's page, from Natural Earth.

Reads Natural Earth's 1:10m land, lakes and rivers (GeoJSON, public domain,
https://www.naturalearthdata.com/), keeps what lies inside the region the
Bible's places cover, simplifies it to about a kilometre and writes the small
binary file the app draws without a connection:

    python pipeline/build_map.py --natural-earth <folder> --out app/assets/map/bible_lands.bin

The folder holds ne_10m_land.geojson, ne_10m_lakes.geojson and
ne_10m_rivers_lake_centerlines.geojson, from
https://github.com/nvkelso/natural-earth-vector (geojson/). Run it again only
when the region or the choices below change; the output is checked in.

Format (little-endian), read by app/lib/features/study/place_map.dart:

    b"BLM1"
    int16 x 4   the region: west, south, east, north, in hundredths of a degree
    3 layers    land (rings, filled even-odd, so holes such as the Caspian Sea
                are rings too), lakes (rings), rivers (lines); each is
      varint    the number of parts, then for each part
      varint    its number of points, then each point as two zigzag varints:
                the step east and north from the point before (the first from
                the region's south-west corner), in hundredths of a degree.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path

MAGIC = b"BLM1"

# West, south, east, north (degrees): every place in Theographic's data but
# India and Uphaz (77°E), from Tarshish in Spain to Ophir, and south past
# Ethiopia.
REGION = (-10.0, 5.0, 70.0, 47.0)

# Coordinates are stored in hundredths of a degree (about a kilometre).
UNITS = 100

# How far a simplified line may stray from Natural Earth's, in degrees.
TOLERANCE = 0.012

# Islands and lakes smaller than this (km²) are left out; Patmos (34 km²) stays.
MIN_AREA_KM2 = 20.0

# Natural lakes only (no modern reservoirs), down to this Natural Earth rank.
LAKE_KINDS = {"Lake", "Alkaline Lake"}
LAKE_MAX_RANK = 5

# The rivers drawn: the Nile and Ethiopia's rivers (the Abay, which Ethiopian
# tradition takes for the Gihon of Genesis 2), Mesopotamia's, and the Jordan.
RIVERS = {
    "Nile", "Rosetta Branch", "Damietta Branch", "El Bahr el Abyad", "Bahr el Jebel",
    "El Bahr el Azraq", "Abay", "Atbara", "Setit", "Tekeze", "Awash", "Omo", "Shebele",
    "Euphrates", "Al Furat", "Firat", "Tigris", "Dicle", "Shatt al Arab", "Karkheh",
    "Jordan",
}
# A river's line through a lake that is drawn would cross the lake; through a
# reservoir that isn't (Lake Nasser, the Euphrates dams) it keeps the river whole.
DRAWN_LAKE_CROSSINGS = {"Abay", "Jordan"}

Point = tuple[float, float]


def _parts(geometry: dict) -> list[list[Point]]:
    """A geometry's rings (polygons) or lines, as lists of (lon, lat)."""
    kind, coords = geometry["type"], geometry["coordinates"]
    if kind == "Polygon":
        return [[(x, y) for x, y, *_ in ring] for ring in coords]
    if kind == "MultiPolygon":
        return [[(x, y) for x, y, *_ in ring] for poly in coords for ring in poly]
    if kind == "LineString":
        return [[(x, y) for x, y, *_ in coords]]
    if kind == "MultiLineString":
        return [[(x, y) for x, y, *_ in line] for line in coords]
    return []


def clip_ring(ring: list[Point], box=REGION) -> list[Point]:
    """The part of a ring inside the box (Sutherland-Hodgman). Edges along the
    box's sides may double back on themselves; they enclose nothing, so the
    filled shape is still the ring's land inside the box."""
    west, south, east, north = box
    edges = [
        (lambda p: p[0] >= west, lambda a, b: _at_x(a, b, west)),
        (lambda p: p[0] <= east, lambda a, b: _at_x(a, b, east)),
        (lambda p: p[1] >= south, lambda a, b: _at_y(a, b, south)),
        (lambda p: p[1] <= north, lambda a, b: _at_y(a, b, north)),
    ]
    out = ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else list(ring)
    for inside, cross in edges:
        points, out = out, []
        if not points:
            break
        prev = points[-1]
        for p in points:
            if inside(p):
                if not inside(prev):
                    out.append(cross(prev, p))
                out.append(p)
            elif inside(prev):
                out.append(cross(prev, p))
            prev = p
    return out


def _at_x(a: Point, b: Point, x: float) -> Point:
    t = (x - a[0]) / (b[0] - a[0])
    return (x, a[1] + t * (b[1] - a[1]))


def _at_y(a: Point, b: Point, y: float) -> Point:
    t = (y - a[1]) / (b[1] - a[1])
    return (a[0] + t * (b[0] - a[0]), y)


def clip_line(line: list[Point], box=REGION) -> list[list[Point]]:
    """The runs of a line inside the box."""
    west, south, east, north = box
    runs, run = [], []
    for p in line:
        if west <= p[0] <= east and south <= p[1] <= north:
            run.append(p)
        else:
            if len(run) > 1:
                runs.append(run)
            run = []
    if len(run) > 1:
        runs.append(run)
    return runs


def simplify(points: list[Point], tolerance: float = TOLERANCE) -> list[Point]:
    """Douglas-Peucker, without recursion (a coastline has tens of thousands of
    points)."""
    if len(points) < 3:
        return list(points)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        far, far_d = -1, tolerance
        for i in range(first + 1, last):
            d = _distance(points[i], points[first], points[last])
            if d > far_d:
                far, far_d = i, d
        if far >= 0:
            keep[far] = True
            stack += [(first, far), (far, last)]
    return [p for p, k in zip(points, keep) if k]


def _distance(p: Point, a: Point, b: Point) -> float:
    """From p to the segment a-b."""
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    if dx == dy == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def simplify_ring(ring: list[Point], tolerance: float = TOLERANCE) -> list[Point]:
    """A closed ring simplified as two halves, split at the point farthest from
    its first one (a ring's two ends are the same point)."""
    if len(ring) < 4:
        return list(ring)
    far = max(range(len(ring)), key=lambda i: math.dist(ring[0], ring[i]))
    a = simplify(ring[: far + 1], tolerance)
    b = simplify(ring[far:] + [ring[0]], tolerance)
    return a[:-1] + b[:-1]


def area_km2(ring: list[Point]) -> float:
    """Roughly, on a sphere flattened at the ring's latitude."""
    if len(ring) < 3:
        return 0.0
    twice = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]))
    lat = sum(y for _, y in ring) / len(ring)
    return abs(twice) / 2 * 111.32**2 * math.cos(math.radians(lat))


def quantize(points: list[Point], box=REGION) -> list[tuple[int, int]]:
    """Hundredths of a degree east and north of the box's corner, without
    repeats."""
    out: list[tuple[int, int]] = []
    for x, y in points:
        q = (round((x - box[0]) * UNITS), round((y - box[1]) * UNITS))
        if not out or out[-1] != q:
            out.append(q)
    return out


def land_rings(features: list[dict]) -> list[list[tuple[int, int]]]:
    return _rings(features, keep=lambda props: True)


def lake_rings(features: list[dict]) -> list[list[tuple[int, int]]]:
    return _rings(
        features,
        keep=lambda p: p.get("featurecla") in LAKE_KINDS and (p.get("scalerank") or 99) <= LAKE_MAX_RANK,
    )


def _rings(features, keep) -> list[list[tuple[int, int]]]:
    out = []
    for f in features:
        if not keep(f["properties"]):
            continue
        for ring in _parts(f["geometry"]):
            clipped = clip_ring(ring)
            if area_km2(clipped) < MIN_AREA_KM2:
                continue
            q = quantize(simplify_ring(clipped))
            if len(q) > 1 and q[0] == q[-1]:
                q.pop()
            if len(q) >= 3:
                out.append(q)
    return out


def river_lines(features: list[dict]) -> list[list[tuple[int, int]]]:
    out = []
    for f in features:
        p = f["properties"]
        name = p.get("name")
        if name not in RIVERS:
            continue
        if p.get("featurecla") == "Lake Centerline" and name in DRAWN_LAKE_CROSSINGS:
            continue
        for line in _parts(f["geometry"]):
            for run in clip_line(line):
                q = quantize(simplify(run))
                if len(q) >= 2:
                    out.append(q)
    return out


def _varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _zigzag(n: int) -> int:
    return n * 2 if n >= 0 else -n * 2 - 1


def encode(layers: list[list[list[tuple[int, int]]]], box=REGION) -> bytes:
    out = bytearray(MAGIC)
    out += struct.pack("<4h", *(round(v * UNITS) for v in box))
    for parts in layers:
        out += _varint(len(parts))
        for part in parts:
            out += _varint(len(part))
            px = py = 0
            for x, y in part:
                out += _varint(_zigzag(x - px)) + _varint(_zigzag(y - py))
                px, py = x, y
    return bytes(out)


def decode(data: bytes):
    """The box and the three layers back, as encode() was given them (for tests)."""
    if data[:4] != MAGIC:
        raise ValueError("not a map file")
    box = tuple(v / UNITS for v in struct.unpack_from("<4h", data, 4))
    pos = 12

    def varint():
        nonlocal pos
        shift = n = 0
        while True:
            b = data[pos]
            pos += 1
            n |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                return n

    def signed():
        n = varint()
        return n // 2 if n % 2 == 0 else -(n + 1) // 2

    layers = []
    for _ in range(3):
        parts = []
        for _ in range(varint()):
            x = y = 0
            part = []
            for _ in range(varint()):
                x += signed()
                y += signed()
                part.append((x, y))
            parts.append(part)
        layers.append(parts)
    if pos != len(data):
        raise ValueError("trailing bytes")
    return box, layers


def build(folder: Path) -> bytes:
    def features(name):
        return json.loads((folder / f"{name}.geojson").read_text(encoding="utf-8"))["features"]

    return encode([
        land_rings(features("ne_10m_land")),
        lake_rings(features("ne_10m_lakes")),
        river_lines(features("ne_10m_rivers_lake_centerlines")),
    ])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--natural-earth", type=Path, required=True, help="folder with the three GeoJSON files")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    data = build(args.natural_earth)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(data)
    _, layers = decode(data)
    counts = ", ".join(f"{name} {len(parts)} parts / {sum(map(len, parts))} points"
                       for name, parts in zip(("land", "lakes", "rivers"), layers))
    print(f"{args.out}: {len(data):,} bytes ({counts})")


if __name__ == "__main__":
    main()
