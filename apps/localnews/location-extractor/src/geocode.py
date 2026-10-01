"""Turning place names into coordinates, without calling anyone.

The first version of this service asked Nominatim, the public OpenStreetMap
geocoder. That works on a laptop and falls apart on stage: Nominatim allows one
request per second per IP, and every pod in this cluster leaves through the same
NAT address. We got rate limited within minutes of the feed scraper starting.

So we look places up in a local dataset instead - 26k cities and 252 countries
that ship inside the image. No network call, no rate limit, same answer every
time. Set LOC_EXT_ONLINE_FALLBACK=true if you want Nominatim consulted for the
names the dataset does not know.
"""

import functools
import os
import threading

import geonamescache

_ONLINE_FALLBACK = os.getenv("LOC_EXT_ONLINE_FALLBACK", "false").lower() == "true"

_index: dict[str, tuple[float, float, str]] = {}
_index_lock = threading.Lock()


def _normalise(name: str) -> str:
    return name.strip().lower().lstrip("the ").strip()


def _build_index() -> dict[str, tuple[float, float, str]]:
    """Name -> (latitude, longitude, display name).

    Cities go in ascending population order so that the biggest place wins a
    name collision: there are 28 places called Berlin, and the audience expects
    the German one.
    """
    cache = geonamescache.GeonamesCache()
    index: dict[str, tuple[float, float, str]] = {}

    cities = sorted(
        cache.get_cities().values(), key=lambda c: c.get("population") or 0
    )
    for city in cities:
        entry = (float(city["latitude"]), float(city["longitude"]), city["name"])
        names = [city["name"]] + list(city.get("alternatenames") or [])
        for name in names:
            index[_normalise(name)] = entry

    # Countries have no coordinates in this dataset, so we point them at their
    # capital. Close enough for a dot on a map.
    for country in cache.get_countries().values():
        capital = country.get("capital")
        if not capital:
            continue
        found = index.get(_normalise(capital))
        if not found:
            continue
        entry = (found[0], found[1], country["name"])
        for key in (country["name"], country["iso"], country["iso3"]):
            if key:
                index[_normalise(key)] = entry

    # Names spaCy hands us that the dataset spells differently.
    for alias, target in {
        "u.s.": "us",
        "u.s.a.": "us",
        "america": "us",
        "uk": "gb",
        "u.k.": "gb",
        "britain": "gb",
        "great britain": "gb",
        "england": "london",
        "holland": "nl",
    }.items():
        if target in index:
            index[alias] = index[target]

    return index


def _get_index() -> dict[str, tuple[float, float, str]]:
    global _index
    if not _index:
        with _index_lock:
            if not _index:
                _index = _build_index()
    return _index


@functools.lru_cache(maxsize=4096)
def geocode(name: str) -> tuple[float, float, str] | None:
    """Return (latitude, longitude, address) for a place name, or None."""
    hit = _get_index().get(_normalise(name))
    if hit:
        return hit
    if _ONLINE_FALLBACK:
        return _geocode_online(name)
    return None


def _geocode_online(name: str) -> tuple[float, float, str] | None:
    from geopy.geocoders import Nominatim

    try:
        # geopy defaults to a one second timeout, which Nominatim rarely meets.
        geolocator = Nominatim(user_agent="ice-demo-location-extractor", timeout=10)
        loc = geolocator.geocode(name)
    except Exception:
        return None
    if not loc:
        return None
    return (loc.latitude, loc.longitude, loc.address)


def warm_up() -> None:
    """Build the index at start-up so the first request is not the slow one."""
    _get_index()
