# Claude Code via ChatGPT subscription (LiteLLM proxy).
# Source this, then run `claude` — it will use your ChatGPT quota.
#
#   source scripts/claude-codex-env.sh
#   claude
#
# The proxy must be running first: scripts/litellm-proxy.sh
# Your normal `claude` in any un-sourced shell is unaffected.

LITELLM_DIR="${LITELLM_DIR:-$HOME/.litellm}"
PROXY_PORT="${PROXY_PORT:-4001}"

export ANTHROPIC_BASE_URL="http://127.0.0.1:${PROXY_PORT}"
export ANTHROPIC_AUTH_TOKEN="$(cat "$LITELLM_DIR/master-key.txt")"

# Model mapping: what Claude Code's model tiers resolve to on ChatGPT.
# gpt-5.6-sol may require ChatGPT Pro/Max and thinks for 30+ min on hard tasks.
export ANTHROPIC_MODEL="gpt-5.5"
export ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-5.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5.3-codex-spark"
export ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-5.6-sol"
export ANTHROPIC_DEFAULT_FABLE_MODEL="gpt-5.6-sol"
