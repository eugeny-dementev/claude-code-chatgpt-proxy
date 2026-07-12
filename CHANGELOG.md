# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versions follow semver.

## [0.1.0] - 2026-07-12

### Added

- `setup.sh`: one-command install. Creates a uv venv, installs pinned
  `litellm[proxy]==1.83.0` (the first release after the 1.82.7/1.82.8
  supply-chain compromise), applies the content-blocks patch, asserts the
  patched behavior, and generates a machine-local auth key.
- `scripts/litellm-proxy.sh`: starts the proxy on port 4001 (configurable via
  `PROXY_PORT`; 4000 avoided because other tools commonly squat it and reset
  HTTP, which surfaces in Claude Code as `ECONNRESET`).
- `scripts/claude-codex-env.sh`: source it and `claude` in that shell runs on
  your ChatGPT quota; every other shell keeps normal Anthropic billing.
- `config/chatgpt-config.yaml`: routes `gpt-5.5`, `gpt-5.3-codex`,
  `gpt-5.3-codex-spark`, and `gpt-5.6-sol` with the two flags the ChatGPT
  backend needs (`supports_system_message: false`, `drop_params: true`).
- `patches/map-system-message-content-blocks.patch`: fixes LiteLLM 1.83.0
  crashing on Anthropic content-block messages
  (`can only concatenate list (not str) to list`).
- Docs: README quick start, `docs/how-it-works.md` (architecture and design
  rationale), `docs/troubleshooting.md` (12 failure modes with fixes).
