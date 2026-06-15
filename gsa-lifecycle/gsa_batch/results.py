"""Extract analysis results from an analysed GSA model and serialise them.

Result extraction uses the GSA COM *Output* API: ``Output_Init`` to configure
an extraction (axis, result header, case, ...) followed by ``Output_Extract``
per entity. The exact ``Output_Init`` header/flag codes are documented in the
GSA COM reference and differ per result type; the defaults below extract node
displacements, and :class:`ResultSpec` lets you target any other result.

See: https://docs.oasys-software.com/structural/gsa/references/com-api/
"""

from __future__ import annotations

import csv
import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING, Iterable, List, Sequence

if TYPE_CHECKING:
    from gsa_batch.com_session import GsaSession

logger = logging.getLogger(__name__)


@dataclass
class ResultSpec:
    """Describe one result extraction.

    Attributes mirror the arguments accepted by the GSA COM ``Output_Init``
    call. ``columns`` names the scalar components returned by ``Output_Extract``
    for a single entity (e.g. the six dof of a nodal displacement) and is used
    only for labelling the output rows.
    """

    name: str
    entity_type: str  # "NODE" or "ELEM"
    result_header: int  # GSA result header code (see COM reference)
    case: str = "A1"  # analysis case, e.g. "A1", or combination "C1"
    axis: int = 0  # 0 = global
    columns: Sequence[str] = ("ux", "uy", "uz", "rxx", "ryy", "rzz")


# Convenience preset: nodal translations + rotations in the global axis.
NODE_DISPLACEMENT = ResultSpec(
    name="node_displacement",
    entity_type="NODE",
    result_header=12,  # adjust to your GSA version's "node displacement" header
    columns=("ux", "uy", "uz", "rxx", "ryy", "rzz"),
)


@dataclass
class ResultTable:
    spec_name: str
    case: str
    columns: List[str]
    rows: List[dict] = field(default_factory=list)

    def to_csv(self, path: Path | str) -> Path:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        fieldnames = ["entity", *self.columns]
        with path.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(self.rows)
        logger.info("Wrote %d rows -> %s", len(self.rows), path)
        return path

    def to_json(self, path: Path | str) -> Path:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "spec": self.spec_name,
            "case": self.case,
            "columns": list(self.columns),
            "rows": self.rows,
        }
        path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        logger.info("Wrote %d rows -> %s", len(self.rows), path)
        return path


def _entity_ids(session: "GsaSession", spec: ResultSpec) -> List[int]:
    """Return the ids of all entities of the requested type.

    Uses the GWA ``HIGHEST`` query to find the entity count, then assumes a
    contiguous 1..N numbering. Override by passing an explicit id list to
    :func:`extract_results` if your model is sparsely numbered.
    """
    highest = session.gwa(f"HIGHEST, {spec.entity_type}")
    try:
        return list(range(1, int(highest) + 1))
    except (TypeError, ValueError):
        return []


def extract_results(
    session: "GsaSession",
    spec: ResultSpec = NODE_DISPLACEMENT,
    entity_ids: Iterable[int] | None = None,
) -> ResultTable:
    """Extract ``spec`` from an already-analysed model in ``session``."""
    com = session.com
    ids = list(entity_ids) if entity_ids is not None else _entity_ids(session, spec)

    logger.info(
        "Extracting %s for %d %s entities (case %s)",
        spec.name,
        len(ids),
        spec.entity_type,
        spec.case,
    )
    # Configure the extraction once for this result header / case / axis.
    com.Output_Init(spec.axis, spec.case, spec.result_header, len(spec.columns))

    table = ResultTable(spec_name=spec.name, case=spec.case, columns=list(spec.columns))
    for entity in ids:
        values = com.Output_Extract(entity, 0)
        # COM returns a tuple/variant array of component values for the entity.
        values = list(values) if not isinstance(values, (int, float)) else [values]
        row = {"entity": entity}
        for col, val in zip(spec.columns, values):
            row[col] = val
        table.rows.append(row)
    return table
