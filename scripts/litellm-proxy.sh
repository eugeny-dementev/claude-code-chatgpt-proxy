#!/bin/bash
# Start the LiteLLM proxy (Claude Code -> ChatGPT subscription).
#
# First run prints a ChatGPT OAuth device code in this terminal — complete it.
# NOTE: the port does not open until the OAuth login finishes ("Waiting for
# application startup" until then). That is expected, not a hang.
#
# Port defaults to 4001 (4000 is a common conflict: NoMachine nxd, other dev
# tools). Override with PROXY_PORT.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${VENV_DIR:-$REPO_DIR/.venv}"
LITELLM_DIR="${LITELLM_DIR:-$HOME/.litellm}"
PROXY_PORT="${PROXY_PORT:-4001}"

umask 077
unset OPENAI_API_KEY ANTHROPIC_API_KEY
export CHATGPT_TOKEN_DIR="$LITELLM_DIR/chatgpt"
source "$VENV_DIR/bin/activate"
export LITELLM_MASTER_KEY="$(cat "$LITELLM_DIR/master-key.txt")"

exec litellm --config "$LITELLM_DIR/chatgpt-config.yaml" --host 127.0.0.1 --port "$PROXY_PORT"
