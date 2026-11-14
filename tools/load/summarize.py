"""Turns the raw k6 summaries and docker stats samples of tools/load/run.sh into Markdown tables.

Usage: uv run python tools/load/summarize.py [raw directory, default docs/specs/load-test/raw]
Reads <label>.json and <label>.stats.tsv, standard library only, prints to stdout. Labels:
  [php-|control-...]route-<route>-v<vus>-r<rep>, mixed-v<vus>-r<rep>, heavy-<route>-v<vus>, soak-v20
"""

import json
import re
import statistics
import sys
from datetime import datetime
from pathlib import Path

WARMUP_SECONDS = 25  # the 15 s warm-up, the 5 s gap and the sign-ins: stats samples before this are dropped
LABEL = re.compile(r"^(?P<prefix>(?:nolog-|free-)?(?:php-)?)(?P<kind>route|mixed|heavy|soak)-(?:(?P<route>[a-z_]+)-)?v(?P<vus>\d+)(?:-r(?P<rep>\d+))?$")


def to_mib(text: str) -> float:
    match = re.match(r"([\d.]+)([KMG]i?B)", text)
    if match is None:
        raise ValueError(f"not a docker memory figure: {text!r}")
    value, unit = match.groups()
    return float(value) * {"KiB": 1 / 1024, "MiB": 1.0, "GiB": 1024.0, "kB": 1 / 1000, "MB": 1.0, "GB": 1000.0}[unit]


def read_stats(path: Path, skip_seconds: int) -> dict[str, dict[str, float]]:
    """Per container role (api, db, gateway, firebase-emulator...): median CPU% and peak memory after the warm-up."""
    if not path.exists():
        return {}
    rows = [line.split("\t") for line in path.read_text().splitlines() if line.count("\t") == 3]
    if not rows:
        return {}
    first = datetime.strptime(rows[0][0], "%H:%M:%S")
    by_role: dict[str, list[tuple[float, float]]] = {}
    for stamp, name, cpu, memory in rows:
        elapsed = (datetime.strptime(stamp, "%H:%M:%S") - first).total_seconds() % 86400
        if elapsed < skip_seconds:
            continue
        role = re.sub(r"^tsr-(app-test-\d+|parity)-", "", name).removesuffix("-1")
        by_role.setdefault(role, []).append((float(cpu.rstrip("%")), to_mib(memory.split(" / ")[0])))
    return {role: {"cpu": statistics.median(c for c, _ in s), "rss": max(m for _, m in s)} for role, s in by_role.items()}


def load(raw: Path) -> list[dict]:
    runs = []
    for path in sorted(raw.glob("*.json")):
        match = LABEL.match(path.stem)
        if not match:
            continue
        data = json.loads(path.read_text())
        skip = 0 if match["kind"] == "heavy" else WARMUP_SECONDS
        runs.append({**match.groupdict(), "vus": int(match["vus"]), "data": data, "stats": read_stats(raw / f"{path.stem}.stats.tsv", skip)})
    return runs


def spread(values: list[float], digits: int = 1) -> str:
    values = [v for v in values if v is not None]
    if not values:
        return "n/a"
    middle = statistics.median(values)
    if len(values) == 1:
        return f"{middle:.{digits}f}"
    return f"{middle:.{digits}f} ({min(values):.{digits}f}-{max(values):.{digits}f})"


def stat(runs: list[dict], role: str, key: str) -> list[float]:
    return [r["stats"][role][key] for r in runs if role in r["stats"]]


def errors(runs: list[dict], summaries: list[dict]) -> str:
    worst = max((s["http_failed_rate"] or 0) for s in summaries)
    codes: dict[str, int] = {}
    short = 0
    for r in runs:
        short += r["data"]["bad_short_body"]
        for code, count in r["data"]["bad_status"].items():
            codes[code] = codes.get(code, 0) + count
    text = f"{worst * 100:.2f}%"
    if codes:
        text += " (" + ", ".join(f"{code}: {count}" for code, count in sorted(codes.items())) + ")"
    if short:
        text += f" short bodies: {short}"
    return text


def row(name: str, vus: int, runs: list[dict], summaries: list[dict]) -> str:
    lat = [s["latency_ms"] for s in summaries if s["latency_ms"]]
    app = "api"
    cells = [
        name, str(vus), str(len(runs)),
        spread([x["p50"] for x in lat]), spread([x["p95"] for x in lat]), spread([x["p99"] for x in lat]),
        spread([s["req_per_s"] for s in summaries], 0), errors(runs, summaries),
        spread(stat(runs, app, "cpu"), 0), spread(stat(runs, app, "rss"), 0), spread(stat(runs, "db", "cpu"), 0),
        spread(stat(runs, "firebase-emulator", "cpu"), 0),
    ]
    return "| " + " | ".join(cells) + " |"


HEADER = ("| Route | VUs | reps | p50 ms | p95 ms | p99 ms | req/s | errors | API CPU% | API RSS MiB | DB CPU% | emulator CPU% |\n"
          "|---|---|---|---|---|---|---|---|---|---|---|---|")


def table(runs: list[dict], prefix: str, kind: str) -> None:
    chosen = [r for r in runs if r["prefix"] == prefix and r["kind"] == kind]
    if not chosen:
        return
    print(f"\n### {prefix or 'new API '}{kind}\n\n{HEADER}")
    keys = sorted({(r["route"] or "mixed", r["vus"]) for r in chosen}, key=lambda k: (k[0], k[1]))
    for route, vus in keys:
        group = [r for r in chosen if (r["route"] or "mixed") == route and r["vus"] == vus]
        print(row(route, vus, group, [r["data"]["all"] for r in group]))
        if kind in ("mixed", "soak"):
            for part in group[0]["data"]["routes"]:
                print(row("- " + part, vus, group, [r["data"]["routes"][part] for r in group]))


def main() -> None:
    raw = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/specs/load-test/raw")
    runs = load(raw)
    for prefix in sorted({r["prefix"] for r in runs}):
        for kind in ("route", "mixed", "heavy", "soak"):
            table(runs, prefix, kind)


if __name__ == "__main__":
    main()
