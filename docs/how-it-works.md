# How it works

Why this repo exists and what each piece does. For setup steps, see the
[README](../README.md). For failures, see [troubleshooting.md](troubleshooting.md).

## The problem

Claude Code only speaks the Anthropic Messages API. A ChatGPT subscription only
serves OpenAI's own clients through its subscription backend. The two don't meet:
you can't point Claude Code at ChatGPT, and buying API credits defeats the point
of a subscription you already pay for.

## The approach

LiteLLM is a proxy that translates between AI provider formats. Run it locally,
tell Claude Code it IS the Anthropic API, and let it forward to ChatGPT:

```
Claude Code                LiteLLM (localhost:4001)           OpenAI
-----------                ------------------------           ------
Anthropic Messages API --> translate request       --------> ChatGPT subscription
  (ANTHROPIC_BASE_URL        - system msg -> user msg          backend (OAuth)
   points here,              - drop Claude-only params
   ANTHROPIC_AUTH_TOKEN =    - map model names
   local master key)     <-- translate response    <--------
```

Claude Code is redirected with nothing but environment variables
(`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, plus the
per-tier `ANTHROPIC_DEFAULT_*_MODEL` overrides). That's why sourcing
`scripts/claude-codex-env.sh` flips one shell to ChatGPT while every other shell
keeps normal Anthropic billing. The repository scripts do not edit Claude Code settings. Existing user settings may
override environment variables; remove conflicting settings if necessary.

## The three compatibility fixes

The ChatGPT subscription backend is not a general-purpose API, and Claude Code
sends Anthropic-shaped requests. Three things bridge the gap:

1. **`supports_system_message: false`** (in `config/chatgpt-config.yaml`).
   The ChatGPT backend rejects system messages outright. This flag makes LiteLLM
   convert them to user messages before forwarding.

2. **`drop_params: true`**. Claude Code sends Anthropic-only parameters such as
   `context_management`. The backend errors on unknown params; this silently
   drops them.

3. **The `map_system_message_pt` patch** (`patches/map-system-message-content-blocks.patch`).
   Fix 1 exposes a bug: LiteLLM 1.83.0's converter assumes message content is a
   plain string, but Claude Code sends Anthropic content blocks,
   `[{"type": "text", "text": "..."}]`. String concatenation on a list throws
   `can only concatenate list (not str) to list`. The patch rewrites the
   converter to flatten content blocks to text first. An upstream PR exists but
   had not landed in 1.83.0. `setup.sh` applies the patch and asserts the fixed
   behavior; re-run it after any LiteLLM reinstall.

## Startup and OAuth: why the port opens late

LiteLLM's ChatGPT provider authenticates with an OAuth device flow, and it runs
that flow during application startup, before uvicorn binds the port. Practical
consequences:

- On first run, the terminal shows a device code and the proxy sits at
  "Waiting for application startup". **Nothing is listening yet.** Claude Code
  started at this moment gets connection errors. Complete the browser login;
  the port opens immediately after.
- Tokens are cached in `~/.litellm/chatgpt/auth.json` (or `$LITELLM_DIR/chatgpt/auth.json`), so later starts don't block. If tokens expire, the
  proxy prompts again the same way: restart it in a terminal you can see.

## Why port 4001, not 4000

The original guide uses 4000. Port 4000 is popular: NoMachine's `nxd`, various
dev servers, and remote-desktop tooling squat it, sometimes from outside your
container's PID namespace where you can't see the owner. The failure mode is
nasty: the foreign service accepts the TCP connection then resets it, so Claude
Code reports `ECONNRESET` and nothing in the LiteLLM logs explains why (LiteLLM
never had the port). Defaulting to 4001 sidesteps the whole class; `PROXY_PORT`
overrides it.

## Why the version pin

`litellm` 1.82.7 and 1.82.8 were compromised with credential-stealing malware on
2026-03-24. This repo pins `1.83.0`, the first release built on LiteLLM's
hardened CI/CD v2 pipeline, and `setup.sh` asserts the installed version.

Check an install for known indicators of the compromised releases:

```bash
find ~ -name "litellm_init.pth" 2>/dev/null   # should find nothing
ls ~/.config/sysmon/ 2>/dev/null              # should not exist
```

## Trade-offs

- **Not parity.** Claude Code's harness is tuned for Claude models. GPT models
  work for general coding, but multi-step agentic flows can behave differently,
  and Spark models handle the harness poorly.
- **A patched dependency.** The venv's LiteLLM differs from upstream by one
  function. Upgrading LiteLLM silently reverts the fix, which is why the version
  is pinned and the patch lives in-repo as a plain diff you can inspect.
- **A local daemon.** You own one more process. The proxy is localhost-only and
  authenticated with a machine-local key, but it is still a process to start
  (or wire into systemd/launchd yourself).
