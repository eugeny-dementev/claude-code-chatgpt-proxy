#!/bin/bash
# One-time setup: uv venv + pinned LiteLLM + compatibility patch + local config.
#
# Usage:
#   ./setup.sh
#
# Requires: uv (https://docs.astral.sh/uv/), openssl.
# Everything is local. No credentials are stored in this repo.
set -euo pipefail
umask 077

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${VENV_DIR:-$REPO_DIR/.venv}"
LITELLM_DIR="${LITELLM_DIR:-$HOME/.litellm}"
PROXY_PORT="${PROXY_PORT:-4001}"

# SECURITY: litellm 1.82.7 and 1.82.8 were compromised with credential-stealing
# malware (2026-03-24). Never install those releases. This newer pin also fixes
# shared stream state in the Anthropic adapter. Recheck patches before upgrading.
LITELLM_VERSION="1.106.6"

echo "==> Creating venv at $VENV_DIR (python 3.12)"
if [ ! -x "$VENV_DIR/bin/python" ]; then
  uv venv "$VENV_DIR" --python 3.12
fi

echo "==> Installing litellm[proxy]==$LITELLM_VERSION"
uv pip install --python "$VENV_DIR/bin/python" "litellm[proxy]==$LITELLM_VERSION" "prisma==0.15.0"

echo "==> Applying LiteLLM compatibility patches"
SITE_PACKAGES="$("$VENV_DIR/bin/python" -c 'import litellm, pathlib; print(pathlib.Path(litellm.__path__[0]).parent)')"
for PATCH_NAME in map-system-message-content-blocks chatgpt-tool-arguments-done; do
  PATCH_FILE="$REPO_DIR/patches/$PATCH_NAME.patch"
  if patch --dry-run -f -d "$SITE_PACKAGES" -p1 < "$PATCH_FILE" >/dev/null 2>&1; then
    patch -f -d "$SITE_PACKAGES" -p1 < "$PATCH_FILE"
  elif patch --dry-run -R -f -d "$SITE_PACKAGES" -p1 < "$PATCH_FILE" >/dev/null 2>&1; then
    echo "    ($PATCH_NAME already applied)"
  else
    echo "Compatibility patch $PATCH_NAME does not match the installed LiteLLM" >&2
    exit 1
  fi
done

echo "==> Verifying patch"
"$VENV_DIR/bin/python" - <<'EOF'
from litellm.litellm_core_utils.prompt_templates.factory import map_system_message_pt
out = map_system_message_pt([
    {"role": "system", "content": [{"type": "text", "text": "be helpful"}]},
    {"role": "user", "content": [{"type": "text", "text": "hi"}]},
])
assert out[0] == {"role": "user", "content": "be helpful"}, out
print("    patch OK:", out[0])
EOF

echo "==> Checking stream isolation and tool argument delivery"
"$VENV_DIR/bin/python" "$REPO_DIR/tests/check_stream_isolation.py"
"$VENV_DIR/bin/python" "$REPO_DIR/tests/test_tool_arguments.py"

echo "==> Writing config + generating local master key in $LITELLM_DIR"
mkdir -p "$LITELLM_DIR/chatgpt"
chmod 700 "$LITELLM_DIR" "$LITELLM_DIR/chatgpt"
cp -n "$REPO_DIR/config/chatgpt-config.yaml" "$LITELLM_DIR/chatgpt-config.yaml" 2>/dev/null \
  || echo "    (kept existing $LITELLM_DIR/chatgpt-config.yaml)"
if [ ! -f "$LITELLM_DIR/master-key.txt" ]; then
  echo "sk-local-$(openssl rand -hex 16)" > "$LITELLM_DIR/master-key.txt"
  chmod 600 "$LITELLM_DIR/master-key.txt"
  echo "    generated $LITELLM_DIR/master-key.txt"
else
  echo "    (kept existing $LITELLM_DIR/master-key.txt)"
fi

echo "==> Verifying install"
"$VENV_DIR/bin/python" -c "import importlib.metadata as m; v=m.version('litellm'); assert v=='$LITELLM_VERSION', v; print('    litellm', v)"

cat <<DONE

Setup complete.

Next steps:
  1. Start the proxy (first run prints a ChatGPT OAuth device code — complete it):
       $REPO_DIR/scripts/litellm-proxy.sh
     The port does not open until the OAuth login finishes; that is expected.
  2. In another terminal:
       source $REPO_DIR/scripts/claude-codex-env.sh
       claude
DONE
