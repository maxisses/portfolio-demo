#!/usr/bin/env python3
"""Liest .env und gibt `export`-Zeilen für die Shell aus (Werte nur auf stdout, für eval).

Die Liste der gesetzten Namen geht auf stderr, Werte nie.
"""
import os
import re
import shlex
import sys

path = os.environ.get("ENV_FILE", ".env")
if not os.path.isfile(path):
    sys.exit(f"parse-env: {path} fehlt")

out = {}
for raw in open(path, encoding="utf-8"):
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("podman login"):
        args = shlex.split(line)
        for i, a in enumerate(args):
            for flag, key in (("-u", "QUAY_USERNAME"), ("--username", "QUAY_USERNAME"),
                              ("-p", "QUAY_PASSWORD"), ("--password", "QUAY_PASSWORD")):
                if a == flag and i + 1 < len(args):
                    out[key] = args[i + 1]
                elif a.startswith(flag + "="):
                    out[key] = a[len(flag) + 1:]
        continue
    if re.fullmatch(r"git@\S+\.git", line):
        out["GIT_REPO_SSH"] = line
        continue
    m = re.fullmatch(r"(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*[:=]\s*(.*)", line)
    if m:
        value = m.group(2).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        out[m.group(1)] = value

for k, v in out.items():
    print(f"export {k}={shlex.quote(v)}")
if not os.environ.get("LOAD_ENV_QUIET"):
    print("load-env: " + " ".join(out), file=sys.stderr)
