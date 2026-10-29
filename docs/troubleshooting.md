# Troubleshooting

Fixes for every failure mode we've hit or that the upstream guide documents.
Background on the moving parts: [how-it-works.md](how-it-works.md).

## `Unable to connect to API (ECONNRESET)` in Claude Code

Two distinct causes. Tell them apart in one command:

```bash
curl -s -m 5 -H "Authorization: Bearer $(cat ~/.litellm/master-key.txt)" \
  http://127.0.0.1:${PROXY_PORT:-4001}/models -o /dev/null -w "HTTP %{http_code}\n"
```

- **`HTTP 200`**: proxy is fine; your Claude Code shell has stale env. Re-run
  `source scripts/claude-codex-env.sh` and check `echo $ANTHROPIC_BASE_URL`
  matches the proxy port.
- **Reset / `HTTP 000` with curl exit 56**: something else owns the port and is
  resetting HTTP. Confirm and pick a new port:

  ```bash
  python3 -c "import socket; s=socket.socket(); s.bind(('0.0.0.0', 4001)); print('free')"
  # OSError: Address already in use -> taken
  PROXY_PORT=4002 ./scripts/litellm-proxy.sh          # terminal 1
  PROXY_PORT=4002 source scripts/claude-codex-env.sh  # terminal 2
  ```

  Note: `ss -tlnp` may show the squatter with no process name if it lives
  outside your container's PID namespace. The bind test above is conclusive
  either way.
- **Connection refused**: the proxy isn't running, or it's still waiting for
  OAuth (see next section).

## Proxy stuck at "Waiting for application startup"

Not a hang. The ChatGPT OAuth device flow runs during startup and the port does
not open until login completes. Scroll up in the proxy terminal for:

```
Sign in with ChatGPT using device code:
1) Visit https://auth.openai.com/codex/device
2) Enter code: XXXX-XXXX
```

Complete the browser login. If the code expired, restart the proxy for a fresh
one. ChatGPT may first require enabling device authentication in your account
settings; follow whatever it shows.

## `can only concatenate list (not str) to list`

The compatibility patch is missing, usually after a LiteLLM reinstall or
upgrade. Re-run:

```bash
./setup.sh
```

and confirm the `patch OK` line. If `patch` reports the hunk already applied,
you're fine. Details on what the patch does: [how-it-works.md](how-it-works.md).

## `System messages are not allowed`

`supports_system_message: false` is missing under `litellm_params` for that
model in `~/.litellm/chatgpt-config.yaml`. Compare against the template in
`config/chatgpt-config.yaml`, fix, restart the proxy.

## `UnsupportedParamsError: chatgpt does not support parameters: ['context_management']`

`drop_params: true` is missing under `litellm_settings` in
`~/.litellm/chatgpt-config.yaml`. Add it, restart the proxy.

## `BadRequestError: The '...-pro' model is not supported when using Codex with a ChatGPT account`

Drop the `-pro` suffix in the config: use `chatgpt/gpt-6-astra`, not
`chatgpt/gpt-6-astra-pro`.

## "Model not found"

Claude Code asked for a model name the proxy doesn't route. List what the proxy
actually serves:

```bash
curl -s -H "Authorization: Bearer $(cat ~/.litellm/master-key.txt)" \
  http://127.0.0.1:${PROXY_PORT:-4001}/models | grep '"id"'
```

Add missing names to `~/.litellm/chatgpt-config.yaml` (both `model_name` and
`model`), restart the proxy.

## 401 / "No api key passed in"

Requests to the proxy need the master key. The env script exports it as
`ANTHROPIC_AUTH_TOKEN`; for manual curl, send
`-H "Authorization: Bearer $(cat ~/.litellm/master-key.txt)"`.

## OAuth token expired

The proxy re-prompts with a new device code on startup. Restart it in a visible
terminal and complete the browser flow again.

## Slow responses

Reasoning duration depends on the model and task. Try `claude --model gpt-6-luna`
for a small task and inspect the proxy logs for errors before retrying.

## Rate limits

Set by your subscription tier. Plus has lower ceilings; Pro/Max are the tiers
meant for heavy agentic use.

## Verify the LiteLLM install is the safe, pinned version

```bash
.venv/bin/python -c "import importlib.metadata as m; print(m.version('litellm'))"
# must print exactly: 1.106.6
find ~ -name "litellm_init.pth" 2>/dev/null   # should find nothing
ls ~/.config/sysmon/ 2>/dev/null              # should not exist
```

Context on why this matters: [how-it-works.md](how-it-works.md), "Why the
version pin".

## Malformed streams with concurrent Claude sessions

LiteLLM 1.83.0 shared an Anthropic event queue across stream instances. Concurrent
requests could consume each other's queued events. In addition, ChatGPT tool
arguments delivered only in a final event were lost, producing empty tool inputs.

Update this fork and run `./setup.sh`, then restart your proxy. The pinned 1.106.6
release fixes stream isolation; the included upstream backport fixes final-event
arguments. Three concurrent Claude sessions with parallel Read calls were tested.
There is no three-session cap configured here. A real HTTP 429 is a separate
condition: inspect its upstream error instead of treating it as stream corruption.
