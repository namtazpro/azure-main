#!/usr/bin/env sh

set -eu

cd "$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

: "${AZURE_SEARCH_ENDPOINT:?AZURE_SEARCH_ENDPOINT was not exported by provisioning}"
: "${FOUNDRY_PROJECT_ENDPOINT:?FOUNDRY_PROJECT_ENDPOINT was not exported by provisioning}"

if [ -z "${AZURE_OPENAI_ENDPOINT:-}" ]; then
  AZURE_OPENAI_ENDPOINT="$(printf '%s' "$FOUNDRY_PROJECT_ENDPOINT" | sed -E 's#\.services\.ai\.azure\.com/api/projects/.*$#.openai.azure.com#')"
  export AZURE_OPENAI_ENDPOINT
fi

attempt=1
until uv run --no-project \
  --with azure-identity \
  --with python-dotenv \
  --with requests \
  python provision_kb.py; do
  if [ "$attempt" -ge 6 ]; then
    echo "Knowledge-base provisioning failed after RBAC propagation retries." >&2
    exit 1
  fi
  echo "Knowledge provisioning attempt $attempt failed; waiting for RBAC propagation." >&2
  attempt=$((attempt + 1))
  sleep 20
done

KB_ENDPOINT="$(azd env get-value KB_MCP_ENDPOINT)"
if [ -z "$KB_ENDPOINT" ]; then
  echo "provision_kb.py did not set KB_MCP_ENDPOINT." >&2
  exit 1
fi

azd ai connection create knowledge-base-mcp --kind remote-tool --force \
  --target "$KB_ENDPOINT" --auth-type project-managed-identity \
  --audience https://search.azure.com --metadata "ApiType=Azure"

azd ai connection create workiq-mail-mcp --kind remote-tool --force \
  --target https://workiq.svc.cloud.microsoft/mcp \
  --auth-type user-entra-token \
  --audience fdcc1f02-fc51-4226-8753-f668596af7f7

create_toolbox() {
  name="$1"
  template="$2"
  if azd ai toolbox show "$name" >/dev/null 2>&1; then
    echo "Toolbox $name already exists; skipping create."
    return
  fi
  temp_dir="$(mktemp -d)"
  temp_file="$temp_dir/toolbox.yaml"
  KB_ENDPOINT="$KB_ENDPOINT" awk '{
    gsub(/\$\{KB_MCP_ENDPOINT\}/, ENVIRON["KB_ENDPOINT"])
    print
  }' "$template" > "$temp_file"
  azd ai toolbox create "$name" --from-file "$temp_file"
  rm -f "$temp_file"
  rmdir "$temp_dir"
}

create_toolbox knowledge-base ./toolbox.yaml
create_toolbox travel-policy-full ./toolbox-full.yaml

PROJECT_ENDPOINT="$(azd env get-value FOUNDRY_PROJECT_ENDPOINT | sed 's#/*$##')"
KNOWLEDGE_TOOLBOX="$PROJECT_ENDPOINT/toolboxes/knowledge-base/mcp?api-version=v1"
FULL_TOOLBOX="$PROJECT_ENDPOINT/toolboxes/travel-policy-full/mcp?api-version=v1"
azd env set TOOLBOX_ENDPOINT "$KNOWLEDGE_TOOLBOX"
azd env set FULL_TOOLBOX_ENDPOINT "$FULL_TOOLBOX"

if [ "${SKIP_WEB_AUTH:-false}" != "true" ]; then
  pwsh "$(dirname "$0")/configure-web-auth.ps1"
fi

echo "Knowledge toolbox: $KNOWLEDGE_TOOLBOX"
echo "Full toolbox: $FULL_TOOLBOX"
