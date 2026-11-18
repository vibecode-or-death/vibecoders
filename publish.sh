#!/usr/bin/env bash
# Создаёт GitHub-репозиторий и пушит текущий коммит.
# При первом запуске попросит войти в GitHub через браузер.

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

REPO_NAME="${REPO_NAME:-vibecoders}"
VISIBILITY="${VISIBILITY:-public}"
DESCRIPTION="Общий репозиторий сообщества Vibecoders: промпты, шаблоны, гайды и цели сервера"

cd "$(dirname "$0")"

if ! gh auth status >/dev/null 2>&1; then
  echo "🔐 Нужно войти в GitHub. Откроется браузер — подтверди вход."
  gh auth login --web --git-protocol https --scopes "repo,read:org"
fi

echo "📦 Создаём репозиторий: $REPO_NAME ($VISIBILITY)"
gh repo create "$REPO_NAME" \
  --"$VISIBILITY" \
  --source=. \
  --remote=origin \
  --push \
  --description "$DESCRIPTION"

echo ""
echo "✅ Готово. Ссылка:"
gh repo view --json url -q .url
