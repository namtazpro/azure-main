"""Orchestrate analysis + result extraction across many GSA models."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Sequence

from gsa_batch.com_session import GsaSession
from gsa_batch.results import NODE_DISPLACEMENT, ResultSpec, extract_results

logger = logging.getLogger(__name__)


@dataclass
class ModelResult:
    model: Path
    analysed_path: Path | None = None
    csv_paths: List[Path] = field(default_factory=list)
    ok: bool = True
    error: str | None = None


def run_batch(
    models: Sequence[Path | str],
    out_dir: Path | str,
    specs: Sequence[ResultSpec] = (NODE_DISPLACEMENT,),
    version: str = "10.2",
    fmt: str = "csv",
) -> List[ModelResult]:
    """Analyse each model and extract ``specs``, writing results to ``out_dir``.

    A single :class:`GsaSession` is reused across all models (the COM object is
    not multi-thread safe, so this runs sequentially by design).
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    results: List[ModelResult] = []

    with GsaSession(version=version) as gsa:
        for raw in models:
            model = Path(raw)
            mr = ModelResult(model=model)
            try:
                gsa.open(model)
                gsa.delete_results()
                gsa.analyse()

                analysed = out_dir / f"{model.stem}_analysed.gwb"
                gsa.save_as(analysed)
                mr.analysed_path = analysed

                for spec in specs:
                    table = extract_results(gsa, spec)
                    target = out_dir / f"{model.stem}__{spec.name}.{fmt}"
                    written = table.to_json(target) if fmt == "json" else table.to_csv(target)
                    mr.csv_paths.append(written)
                logger.info("OK: %s", model.name)
            except Exception as exc:  # noqa: BLE001 - report failure, keep batch going
                mr.ok = False
                mr.error = str(exc)
                logger.error("FAILED: %s -> %s", model.name, exc)
            results.append(mr)

    return results
