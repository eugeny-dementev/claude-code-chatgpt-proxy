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

# Only the local gateway token is used; do not inherit upstream API billing keys.
export ANTHROPIC_API_KEY=""
export OPENAI_API_KEY=""
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export ANTHROPIC_MODEL="gpt-6.1-sol"
export ANTHROPIC_DEFAULT_SONNET_MODEL="gpt-6.1-sol"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-6-luna"
export ANTHROPIC_SMALL_FAST_MODEL="gpt-6-luna"
export ANTHROPIC_DEFAULT_OPUS_MODEL="gpt-6-astra"
export ANTHROPIC_DEFAULT_FABLE_MODEL="gpt-6-astra"
export CLAUDE_CODE_SUBAGENT_MODEL="gpt-6.1-sol"
