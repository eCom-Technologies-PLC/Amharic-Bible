"""The map of Bible lands (build_map.py) and the file the app draws it from."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build_map  # noqa: E402

ASSET = Path(__file__).resolve().parents[2] / "app" / "assets" / "map" / "bible_lands.bin"


def feature(props, kind, coords):
    return {"properties": props, "geometry": {"type": kind, "coordinates": coords}}


def inside(rings, lon, lat, box=build_map.REGION):
    """Even-odd: whether a point is inside the rings (as the app fills them)."""
    x, y = (lon - box[0]) * build_map.UNITS, (lat - box[1]) * build_map.UNITS
    hit = False
    for ring in rings:
        for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
            if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
                hit = not hit
    return hit


class BuildMapTest(unittest.TestCase):
    def test_a_ring_is_cut_at_the_regions_edge(self):
        square = [(-12.0, 10.0), (-8.0, 10.0), (-8.0, 12.0), (-12.0, 12.0), (-12.0, 10.0)]
        clipped = build_map.clip_ring(square)
        self.assertEqual(min(x for x, _ in clipped), -10.0)
        self.assertAlmostEqual(build_map.area_km2(clipped), build_map.area_km2(square[:-1]) / 2, delta=1)
        self.assertEqual(build_map.clip_ring([(80.0, 10.0), (82.0, 10.0), (81.0, 12.0)]), [])

    def test_lines_are_simplified_and_cut(self):
        straight = [(30.0 + i / 100, 30.0) for i in range(101)]
        self.assertEqual(build_map.simplify(straight), [straight[0], straight[-1]])
        bend = [(30.0, 30.0), (30.5, 30.5), (31.0, 30.0)]
        self.assertEqual(build_map.simplify(bend), bend)
        self.assertEqual(build_map.clip_line([(69.0, 30.0), (69.5, 30.0), (71.0, 30.0), (72.0, 30.0)]),
                         [[(69.0, 30.0), (69.5, 30.0)]])

    def test_a_ring_keeps_its_corners(self):
        square = [(30.0, 30.0), (31.0, 30.0), (31.0, 31.0), (30.0, 31.0), (30.0, 30.0)]
        self.assertEqual(sorted(build_map.simplify_ring(square)), sorted(square[:4]))

    def test_small_islands_and_reservoirs_are_left_out(self):
        island = [(33.0, 33.0), (33.01, 33.0), (33.01, 33.01), (33.0, 33.0)]  # about 0.5 km²
        cyprus = [(32.3, 34.6), (34.6, 34.6), (34.6, 35.7), (32.3, 35.7), (32.3, 34.6)]
        land = build_map.land_rings([feature({}, "MultiPolygon", [[island], [cyprus]])])
        self.assertEqual(len(land), 1)
        lakes = build_map.lake_rings([
            feature({"featurecla": "Reservoir", "scalerank": 5, "name": "Lake Nasser"}, "Polygon", [cyprus]),
            feature({"featurecla": "Lake", "scalerank": 5, "name": "Sea of Galilee"}, "Polygon", [cyprus]),
            feature({"featurecla": "Lake", "scalerank": 8, "name": "Lake Adobed"}, "Polygon", [cyprus]),
        ])
        self.assertEqual(len(lakes), 1)

    def test_rivers_are_the_chosen_ones_and_skip_lakes_that_are_drawn(self):
        line = [(35.5, 32.0), (35.6, 32.5)]
        rivers = build_map.river_lines([
            feature({"name": "Jordan", "featurecla": "River"}, "LineString", line),
            feature({"name": "Jordan", "featurecla": "Lake Centerline"}, "LineString", line),
            feature({"name": "Nile", "featurecla": "Lake Centerline"}, "LineString", line),
            feature({"name": "Danube", "featurecla": "River"}, "LineString", line),
        ])
        self.assertEqual(len(rivers), 2)

    def test_the_encoding_round_trips(self):
        layers = [[[(0, 0), (8000, 4200), (5, 7)]], [], [[(1, 2), (1, 300)], [(7999, 1)]]]
        box, back = build_map.decode(build_map.encode(layers))
        self.assertEqual(box, build_map.REGION)
        self.assertEqual(back, layers)


class MapAssetTest(unittest.TestCase):
    """The checked-in file: rebuild it with build_map.py when this fails."""

    @classmethod
    def setUpClass(cls):
        cls.box, (cls.land, cls.lakes, cls.rivers) = build_map.decode(ASSET.read_bytes())

    def test_it_covers_the_region(self):
        self.assertEqual(self.box, build_map.REGION)
        self.assertLess(ASSET.stat().st_size, 64 * 1024)

    def test_land_and_sea_where_they_are(self):
        for name, lat, lon in [("Jerusalem", 31.78, 35.23), ("Babylon", 32.54, 44.42), ("Rome", 41.9, 12.5),
                               ("Addis Ababa", 9.03, 38.74), ("Patmos", 37.31, 26.55), ("Malta", 35.9, 14.4)]:
            self.assertTrue(inside(self.land, lon, lat), name)
        for name, lat, lon in [("the Mediterranean", 33.0, 33.0), ("the Red Sea", 20.0, 38.5),
                               ("the Caspian Sea", 42.0, 50.5), ("the Persian Gulf", 27.0, 51.0)]:
            self.assertFalse(inside(self.land, lon, lat), name)

    def test_the_lakes_of_the_bible_and_of_ethiopia(self):
        for name, lat, lon in [("the Sea of Galilee", 32.82, 35.59), ("the Dead Sea", 31.5, 35.5),
                               ("Lake Tana", 12.0, 37.3)]:
            self.assertTrue(inside(self.lakes, lon, lat), name)

    def test_the_jordan_flows_between_them(self):
        def near(lat, lon):
            x, y = (lon - self.box[0]) * build_map.UNITS, (lat - self.box[1]) * build_map.UNITS
            return any(abs(px - x) < 10 and abs(py - y) < 10 for line in self.rivers for px, py in line)

        self.assertTrue(near(32.3, 35.56), "the Jordan")
        self.assertTrue(near(33.3, 44.4), "the Tigris at Baghdad")


if __name__ == "__main__":
    unittest.main()
