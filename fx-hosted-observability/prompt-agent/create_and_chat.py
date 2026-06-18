"""Prompt agent: declare it, then chat with it.

The agent itself is just a definition stored in Foundry. There is no container,
no server, no deploy. Foundry runs the agent loop on its shared runtime.
"""

import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

load_dotenv()

PROJECT_ENDPOINT = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
MODEL = os.environ["AZURE_AI_MODEL_DEPLOYMENT_NAME"]
AGENT_NAME = "demo-prompt-agent"


def main() -> None:
    project = AIProjectClient(
        endpoint=PROJECT_ENDPOINT,
        credential=DefaultAzureCredential(),
    )

    # 1) Register an immutable version of the agent definition.
    agent = project.agents.create_version(
        agent_name=AGENT_NAME,
        definition=PromptAgentDefinition(
            model=MODEL,
            instructions=(
                "You are a concise geography tutor. Answer in one short sentence "
                "and include the units."
            ),
        ),
    )
    print(f"Registered agent name={agent.name} version={agent.version}")

    # 2) Chat with it via the Responses API, referencing the agent by name.
    openai = project.get_openai_client()
    conversation = openai.conversations.create()

    first = openai.responses.create(
        conversation=conversation.id,
        extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
        input="What is the size of France in square miles?",
    )
    print("Q1:", first.output_text)

    follow_up = openai.responses.create(
        conversation=conversation.id,
        extra_body={"agent_reference": {"name": AGENT_NAME, "type": "agent_reference"}},
        input="And what is the capital city?",
    )
    print("Q2:", follow_up.output_text)


if __name__ == "__main__":
    main()
