"""Command-line entry point for batch GSA analysis.

Examples
--------
Analyse every model in ``./models`` and write CSV results to ``./out``::

    python -m gsa_batch.cli --input models --out out

Analyse specific files, emit JSON, target GSA 10.1::

    python -m gsa_batch.cli a.gwb b.gwb --out out --format json --gsa-version 10.1
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path
from typing import List

from gsa_batch.runner import run_batch


def _collect_models(args: argparse.Namespace) -> List[Path]:
    models: List[Path] = [Path(p) for p in args.models]
    if args.input:
        models.extend(sorted(Path(args.input).glob("*.gwb")))
    # de-duplicate while preserving order
    seen, unique = set(), []
    for m in models:
        if m not in seen:
            seen.add(m)
            unique.append(m)
    return unique


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="gsa-batch", description=__doc__)
    parser.add_argument("models", nargs="*", help="Explicit .gwb model paths")
    parser.add_argument("--input", help="Folder to scan for *.gwb models")
    parser.add_argument("--out", default="out", help="Output directory (default: out)")
    parser.add_argument(
        "--format", choices=("csv", "json"), default="csv", help="Result file format"
    )
    parser.add_argument("--gsa-version", default="10.2", help="Installed GSA version")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
    )

    models = _collect_models(args)
    if not models:
        parser.error("no models given; pass paths and/or --input FOLDER")

    results = run_batch(
        models, out_dir=args.out, version=args.gsa_version, fmt=args.format
    )

    failures = [r for r in results if not r.ok]
    for r in results:
        status = "OK " if r.ok else "ERR"
        detail = r.error if not r.ok else f"{len(r.csv_paths)} result file(s)"
        print(f"[{status}] {r.model.name}: {detail}")

    print(f"\n{len(results) - len(failures)}/{len(results)} models analysed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
