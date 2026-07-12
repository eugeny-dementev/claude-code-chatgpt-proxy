# claude-code-chatgpt-proxy

Run Claude Code on your existing ChatGPT Plus/Pro/Max subscription. No API key,
no separate billing. Your normal `claude` command stays untouched: you source one
env file in a shell, and `claude` in that shell routes through your ChatGPT quota.

The mechanism is [LiteLLM](https://github.com/BerriAI/litellm) running as a local
proxy. Claude Code speaks the Anthropic API to `127.0.0.1:4001`; LiteLLM forwards
to OpenAI's ChatGPT subscription backend using OAuth device-flow auth.

Based on the setup described in
[Run Claude Code with Your ChatGPT Subscription](https://prabal.ca/posts/claude-code-chatgpt-subscription/)
by Prabal Gupta, repackaged for Linux with [uv](https://docs.astral.sh/uv/) instead
of conda, with the LiteLLM compatibility patch applied automatically and the port
moved off 4000 (a common conflict). See [docs/how-it-works.md](docs/how-it-works.md)
for what each piece does.

## What you get

```
you type:  claude "fix this test"
           |
           v  Anthropic API format
LiteLLM proxy (127.0.0.1:4001)
           |
           v  ChatGPT subscription backend (your OAuth login)
gpt-5.5 / gpt-5.3-codex / gpt-5.6-sol
```

- No credentials in this repo, ever. The auth key is generated on your machine at
  setup time; ChatGPT OAuth tokens are stored by LiteLLM locally.
- Pinned `litellm==1.83.0`. Versions 1.82.7 and 1.82.8 were compromised with
  credential-stealing malware (2026-03-24); 1.83.0 is the first release from the
  hardened CI/CD v2 pipeline. `setup.sh` verifies the installed version.

## Requirements

- Linux or macOS
- [uv](https://docs.astral.sh/uv/) on PATH
- `openssl`, `patch` (standard on most systems)
- [Claude Code](https://claude.com/claude-code) installed
- A ChatGPT Plus, Pro, or Max subscription

## Quick start

Step 1. Clone and run setup:

```bash
git clone https://github.com/9prodhi/claude-code-chatgpt-proxy.git
cd claude-code-chatgpt-proxy
./setup.sh
```

You should see `patch OK`, `litellm 1.83.0`, and `Setup complete.`

Step 2. Start the proxy and complete the one-time ChatGPT login:

```bash
./scripts/litellm-proxy.sh
```

The terminal prints a device code:

```
Sign in with ChatGPT using device code:
1) Visit https://auth.openai.com/codex/device
2) Enter code: XXXX-XXXX
```

Open the URL, log in with your OpenAI account, enter the code. **The proxy's port
does not open until this login finishes** ("Waiting for application startup" is
expected, not a hang). After login you'll see `Uvicorn running on http://0.0.0.0:4001`.
Tokens are saved locally; future starts don't prompt.

Step 3. In another terminal, run Claude Code through it:

```bash
source scripts/claude-codex-env.sh
claude
```

That's it. `claude` in this shell bills your ChatGPT subscription. `claude` in any
other shell is your normal Anthropic account.

## Model mapping

What Claude Code's model tiers resolve to (set in `scripts/claude-codex-env.sh`):

| Claude Code tier | ChatGPT model | Notes |
|---|---|---|
| default / Sonnet | `gpt-5.5` | Strong all-rounder, works on Plus |
| Haiku (fast) | `gpt-5.3-codex-spark` | Fast code tasks, works on Plus |
| Opus / Fable | `gpt-5.6-sol` | Deep reasoning. May require Pro/Max. 30+ min thinking is normal |

Switch per-session: `claude --model gpt-5.3-codex`.

Model names drift. If your ChatGPT model picker shows different names, edit both
`model_name` and `model` in `~/.litellm/chatgpt-config.yaml` and restart the proxy.

## Configuration

All knobs are environment variables read by `setup.sh` and both scripts:

| Variable | Default | Effect |
|---|---|---|
| `VENV_DIR` | `<repo>/.venv` | Where the Python venv lives |
| `LITELLM_DIR` | `~/.litellm` | Config, master key, OAuth token storage |
| `PROXY_PORT` | `4001` | Proxy listen port. Keep off 4000 (NoMachine and other tools squat it) |

Files on your machine after setup:

| Path | Purpose | In repo? |
|---|---|---|
| `~/.litellm/chatgpt-config.yaml` | Model routing config | template in `config/` |
| `~/.litellm/master-key.txt` | Local auth key between Claude Code and the proxy | **never** |
| `<repo>/.venv/` | LiteLLM install (patched) | gitignored |

## Known limitations

Claude Code's harness (system prompts, tool-use patterns, agent loops) is built
for Claude models. Most GPT models handle general coding fine through this setup,
but agentic multi-step workflows may behave differently than with Claude. The
Spark model in particular does not play well with the harness. It works; don't
expect parity.

Rate limits come from your subscription tier: Plus has lower ceilings, Pro and
Max suit heavy agentic use.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md). The two you'll most likely
hit:

- **`Unable to connect to API (ECONNRESET)`**: something else owns your port, or
  the proxy is still waiting for OAuth. Details in the doc.
- **`can only concatenate list (not str) to list`**: the LiteLLM patch didn't
  apply. Re-run `./setup.sh` and check for `patch OK`.

## Security notes

- Nothing in this repo contains or transmits credentials. Verify yourself:
  the master key is generated by `openssl rand` in `setup.sh`, OAuth tokens are
  handled by LiteLLM's ChatGPT provider on your machine.
- The master key only authenticates localhost traffic between Claude Code and
  your own proxy. Treat `~/.litellm/` as private anyway (`master-key.txt` is 600).
- After any LiteLLM upgrade, re-check the supply-chain advisory before unpinning
  1.83.0, and re-apply the patch if the upstream fix hasn't landed
  (`./setup.sh` is idempotent and safe to re-run).

## License

MIT. See [LICENSE](LICENSE).
