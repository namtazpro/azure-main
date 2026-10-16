# Copyright (c) Microsoft. All rights reserved.

import asyncio
import os

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import FoundryToolbox, ResponsesHostServer
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

load_dotenv()

_BASE_INSTRUCTIONS = """You are the Corporate Travel Policy Assistant.

Use the Foundry IQ knowledge-base tool for every travel-policy question.
Present exact amounts, deadlines, vendors, approval levels, and exceptions.
Label knowledge-base findings as "Standing Policy" and cite the retrieved
sources. If the policy corpus does not contain the answer, say so instead of
guessing.
"""

_WORKIQ_INSTRUCTIONS = """

For every policy question, also use Work IQ Mail to look for recent policy
updates, budget freezes, approvals, or temporary exceptions. Use broad,
topic-level searches. Label these results as "Recent Update (Mail)" and include
the subject, sender, and date when available. If mail conflicts with the
standing policy, show both and clearly explain that the recent authorized
override takes precedence. Never invent mail results.
"""


def _instructions() -> str:
    if os.environ.get("ENABLE_WORKIQ", "false").lower() == "true":
        return _BASE_INSTRUCTIONS + _WORKIQ_INSTRUCTIONS
    return _BASE_INSTRUCTIONS


async def main() -> None:
    credential = DefaultAzureCredential()
    toolbox = FoundryToolbox(credential, name="travel_iq")
    client = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"],
        credential=credential,
    )
    agent = Agent(
        client=client,
        name="TravelPolicyAgent",
        instructions=_instructions(),
        tools=toolbox,
        default_options={"store": False},
    )

    server = ResponsesHostServer(agent)
    await server.run_async()


if __name__ == "__main__":
    asyncio.run(main())
