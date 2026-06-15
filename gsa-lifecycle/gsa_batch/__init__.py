"""Batch automation for Oasys GSA structural analysis via the COM API.

This package drives a locally installed, licensed copy of Oasys GSA to:
  * open one or more ``.gwb`` models,
  * (re)run all analysis tasks,
  * extract nodal/element results, and
  * write them to CSV/JSON for downstream use or CI gating.

Requires Windows + an installed, licensed Oasys GSA (10.2 by default) and
``pywin32`` for COM interop.
"""

__all__ = ["GsaSession", "run_batch", "extract_results"]

from gsa_batch.com_session import GsaSession
from gsa_batch.results import extract_results
from gsa_batch.runner import run_batch
