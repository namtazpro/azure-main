from pathlib import Path
import re
from unittest import TestCase

from provision_kb import create_knowledge_source, load_documents


class TravelPolicyContentTests(TestCase):
    def test_travel_policy_content_is_valid(self) -> None:
        data_path = (
            Path(__file__).resolve().parents[3] / "knowledge" / "travel-policies.json"
        )
        documents = load_documents(data_path)

        self.assertEqual(len(documents), 10)
        self.assertGreaterEqual(
            {document["category"] for document in documents},
            {"Approvals", "Hotels", "Expenses", "International"},
        )
        self.assertTrue(
            any("$250/night" in document["content"] for document in documents)
        )
        self.assertTrue(
            all(document["title"] and document["content"] for document in documents)
        )
        self.assertTrue(
            all(re.fullmatch(r"[A-Za-z0-9_\-=]+", document["id"]) for document in documents)
        )

    def test_knowledge_source_uses_field_reference_objects(self) -> None:
        calls: list[tuple[str, dict]] = []

        class RecordingClient:
            def put(self, path: str, body: dict) -> None:
                calls.append((path, body))

        create_knowledge_source(
            RecordingClient(), "travel-policy-source", "travel-policy-index"
        )

        parameters = calls[0][1]["searchIndexParameters"]
        self.assertTrue(
            all(set(field) == {"name"} for field in parameters["sourceDataFields"])
        )
        self.assertTrue(
            all(set(field) == {"name"} for field in parameters["searchFields"])
        )
