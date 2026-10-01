"""Location Extractor - the NLP microservice of the LocalNews demo app.

Takes a piece of text, finds the places mentioned in it and turns those place
names into coordinates. Two ways to find the places:

- spacy (default): the small language model inside the container
- llm: ask a model behind Models-as-a-Service (OpenAI-compatible API).
  Needs MAAS_BASE_URL, MAAS_API_KEY and MAAS_MODEL, which the platform injects
  from the secret the catalog item created. If the model does not answer, we
  fall back to spaCy, so the app keeps working.
"""

import json
import os
import random
import urllib.request

import spacy
from flask import Flask, jsonify, request
from prometheus_client import Counter, Info, generate_latest

from src import geocode as geo

# --- the bit we change live on stage -----------------------------------
GREETING = "Lets go!!!"
# -----------------------------------------------------------------------

VERSION = os.getenv("LOC_EXT_VERSION", "dev")

# Two stories about Berlin would otherwise land on the same pixel, so we
# scatter the markers a little. 0.3 degrees is roughly 30 km - enough to see
# them apart, small enough to stay in the right city.
JITTER = 0.3

COUNTER_LOCATIONS_EXTRACTED = Counter(
    "locations_extracted", "Number of extracted locations"
)
COUNTER_LOCATIONS_UNKNOWN = Counter(
    "locations_unknown", "Place names spaCy found but we could not geocode"
)
INFO_LOCATION_EXTRACTOR = Info(
    "location_extractor", "Information regarding the location extractor"
)
INFO_LOCATION_EXTRACTOR.info({"version": VERSION})

EXTRACTOR = os.getenv("EXTRACTOR", "spacy")
MAAS_BASE_URL = os.getenv("MAAS_BASE_URL", "").rstrip("/")
MAAS_API_KEY = os.getenv("MAAS_API_KEY", "")
MAAS_MODEL = os.getenv("MAAS_MODEL", "")
USE_LLM = EXTRACTOR == "llm" and MAAS_BASE_URL and MAAS_API_KEY and MAAS_MODEL

COUNTER_LLM_CALLS = Counter(
    "location_extractor_llm_calls", "Requests to the model behind MaaS", ["result"]
)

PROMPT = (
    "Extract every geographic place mentioned in the news text below: countries, "
    "regions, cities. Answer with a JSON array of the place names in English and "
    "nothing else. If there is no place, answer [].\n\nText: "
)

nlp = spacy.load("en_core_web_md")
geo.warm_up()

app = Flask(__name__)


@app.get("/")
def home():
    return jsonify(
        {
            "greeting": GREETING,
            "version": VERSION,
            "extractor": "llm (" + MAAS_MODEL + ")" if USE_LLM else "spacy",
            "usage": '/get_loc?text="..."',
        }
    )


def _names_via_llm(text):
    """Ask the model behind MaaS for place names. None means: use spaCy instead."""
    body = json.dumps(
        {
            "model": MAAS_MODEL,
            "messages": [{"role": "user", "content": PROMPT + text[:4000]}],
            "max_tokens": 200,
            "temperature": 0,
        }
    ).encode()
    req = urllib.request.Request(
        MAAS_BASE_URL + "/chat/completions",
        data=body,
        headers={
            "Authorization": "Bearer " + MAAS_API_KEY,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            answer = json.load(resp)["choices"][0]["message"]["content"]
        start, end = answer.find("["), answer.rfind("]")
        names = json.loads(answer[start : end + 1]) if start >= 0 else []
        COUNTER_LLM_CALLS.labels(result="ok").inc()
        return [n for n in names if isinstance(n, str) and n.strip()]
    except Exception as err:  # model down, rate limit, bad JSON: keep the app running
        print("LLM extraction failed, falling back to spaCy: " + str(err), flush=True)
        COUNTER_LLM_CALLS.labels(result="error").inc()
        return None


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok", "version": VERSION})


@app.get("/get_loc")
def get_coords():
    text = request.args.get("text", "")
    print("Analyzing this text: " + text, flush=True)

    names = _names_via_llm(text) if USE_LLM else None
    if names is None:
        doc = nlp(text)
        names = [ent.text for ent in doc.ents if ent.label_ in ("GPE", "LOC")]
    else:
        print("The model behind MaaS recognised: " + str(names), flush=True)

    if not names:
        print("Not found any location in this text", flush=True)
        return _json(_fallback())

    print("Those entities were recognized as locations: " + str(names), flush=True)

    found = {}
    for idx, name in enumerate(names):
        # Hack to simulate a worse-performing model in case of version v2
        if VERSION == "v2-worse-performance" and random.randint(0, 1) == 0:
            continue

        hit = geo.geocode(name)
        if not hit:
            print("no coordinates for this location: " + name, flush=True)
            COUNTER_LOCATIONS_UNKNOWN.inc()
            continue

        latitude, longitude, address = hit
        found[idx + 1] = {
            "extracted location": name,
            "generated address": address,
            "latitude": latitude + random.uniform(-JITTER, JITTER),
            "longitude": longitude + random.uniform(-JITTER, JITTER),
        }
        print("found lat & long for this location: " + name, flush=True)
        COUNTER_LOCATIONS_EXTRACTED.inc()

    return _json(found or _fallback())


def _fallback():
    """Nothing recognised - drop a marker somewhere in the ocean."""
    return {
        "1": {
            "extracted location": "none",
            "generated address": "Brisbane City, Queensland, Australia",
            "latitude": 0.4689682 - random.uniform(0.1, 5),
            "longitude": -30.0234991 + random.uniform(0.1, 5),
        }
    }


def _json(payload):
    return (
        json.dumps(payload),
        200,
        {"Content-Type": "application/json; charset=utf-8"},
    )


@app.get("/metrics")
def metrics():
    return generate_latest()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
