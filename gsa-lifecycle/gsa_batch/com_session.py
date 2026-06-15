"""Thin context-managed wrapper around the Oasys GSA COM automation object.

The COM verbs used here are taken from the official Oasys sample
(``Gsa_10_2.ComAuto``): ``Open``, ``Delete``, ``Analyse``, ``SaveAs``,
``Close`` and the general ``GwaCommand`` gateway.

See: https://docs.oasys-software.com/structural/gsa/references/com-api/
"""

from __future__ import annotations

import logging
from pathlib import Path
from types import TracebackType
from typing import Optional, Type

logger = logging.getLogger(__name__)


class GsaError(RuntimeError):
    """Raised when a GSA COM call returns a non-success status."""


class GsaSession:
    """Manage the lifecycle of a single GSA COM automation instance.

    Use as a context manager so the COM object is always released::

        with GsaSession() as gsa:
            gsa.open(model)
            gsa.analyse()
            gsa.save_as(out)
    """

    def __init__(self, version: str = "10.2") -> None:
        # ProgID is version-bound, e.g. "Gsa_10_2.ComAuto" for GSA 10.2.
        self._prog_id = f"Gsa_{version.replace('.', '_')}.ComAuto"
        self._gsa = None

    # -- lifecycle ---------------------------------------------------------
    def __enter__(self) -> "GsaSession":
        import win32com.client  # imported lazily so the module loads off-Windows

        logger.info("Dispatching GSA COM object: %s", self._prog_id)
        self._gsa = win32com.client.Dispatch(self._prog_id)
        return self

    def __exit__(
        self,
        exc_type: Optional[Type[BaseException]],
        exc: Optional[BaseException],
        tb: Optional[TracebackType],
    ) -> None:
        if self._gsa is not None:
            try:
                self._gsa.Close()
            finally:
                self._gsa = None

    @property
    def com(self):
        """The raw COM object, for calls not wrapped here."""
        if self._gsa is None:
            raise GsaError("GSA session is not open; use 'with GsaSession() as gsa:'")
        return self._gsa

    # -- model operations --------------------------------------------------
    def open(self, path: Path | str) -> None:
        path = Path(path)
        if not path.is_file():
            raise FileNotFoundError(path)
        logger.info("Opening model: %s", path)
        self._check(self.com.Open(str(path)), f"Open({path})")

    def new(self) -> None:
        logger.info("Creating new blank model")
        self._check(self.com.New(), "New()")

    def delete_results(self) -> None:
        logger.info("Deleting existing results")
        # GwaCommand-style verb; tolerant of models that have no results yet.
        self.com.Delete("RESULTS")

    def analyse(self, task: Optional[int] = None) -> None:
        """Run analysis tasks. With no argument GSA analyses *all* tasks."""
        logger.info("Analysing (%s)", "all tasks" if task is None else f"task {task}")
        status = self.com.Analyse() if task is None else self.com.Analyse(task)
        self._check(status, "Analyse()")

    def save_as(self, path: Path | str) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        logger.info("Saving analysed model: %s", path)
        self._check(self.com.SaveAs(str(path)), f"SaveAs({path})")

    def gwa(self, command: str) -> object:
        """Send a raw GWA command (e.g. 'GET, NODE.3, 1') and return the result."""
        return self.com.GwaCommand(command)

    # -- helpers -----------------------------------------------------------
    @staticmethod
    def _check(status: object, what: str) -> None:
        """GSA COM verbs return 0/1 on success; raise otherwise.

        Status conventions vary slightly by verb, so treat ``0`` and ``1``
        (and ``None``) as success and anything else as an error.
        """
        if status not in (0, 1, None):
            raise GsaError(f"{what} failed with status {status!r}")
