#!/usr/bin/env bash
# Переносит репозиторий в организацию и настраивает команды.
# Перед запуском создай организацию: https://github.com/organizations/new

set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

ORG="${ORG:-vibecoders-hq}"
REPO="${REPO:-vibecoders}"
MEMBERS="${ORG_MEMBERS:-}"   # например: user1,user2,user3

cd "$(dirname "$0")"

echo "🔎 Проверяем организацию $ORG ..."
if ! gh api "/orgs/$ORG" >/dev/null 2>&1; then
  echo "❌ Организация $ORG не найдена."
  echo "   Создай её здесь: https://github.com/organizations/new"
  echo "   Owner: niasikwq, Organization name: $ORG"
  exit 1
fi

echo "📦 Переносим $REPO → $ORG ..."
gh api -X POST "repos/niasikwq/$REPO/transfer" \
  -f new_owner="$ORG" \
  -H "Accept: application/vnd.github+json" >/dev/null

git remote set-url origin "https://github.com/$ORG/$REPO.git"
git fetch origin

echo "⚙️  Настраиваем организацию ..."
gh api -X PATCH "/orgs/$ORG" \
  -f name="Vibecoders HQ" \
  -f description="Сообщество вайбкодеров: промпты, шаблоны, гайды и цели сервера" \
  -f default_repository_permission=write \
  -F members_can_create_repositories=false \
  >/dev/null 2>&1 || echo "   ⚠️  Не удалось обновить настройки (нужен scope admin:org)"

echo "👥 Создаём команды ..."
for team in core contributors; do
  desc="Команда $ORG: $team"
  gh api -X POST "/orgs/$ORG/teams" \
    -f name="$team" \
    -f description="$desc" \
    -f privacy=closed >/dev/null 2>&1 \
    && echo "   ✅ team: $team" \
    || echo "   ⚠️  team $team уже есть или нет прав (нужен admin:org)"
done

gh api -X PUT "/orgs/$ORG/teams/core/repos/$ORG/$REPO" -f permission=push >/dev/null 2>&1 \
  && echo "   ✅ core → push доступ к репозиторию" \
  || echo "   ⚠️  не удалось привязать команду к репозиторию"

if [ -n "$MEMBERS" ]; then
  echo "📨 Приглашаем участников ..."
  IFS=',' read -ra users <<< "$MEMBERS"
  for user in "${users[@]}"; do
    user="$(echo "$user" | xargs)"
    [ -z "$user" ] && continue
    gh api -X POST "/orgs/$ORG/invitations" \
      -f invitee="$user" \
      -F teams="[\"core\"]" >/dev/null 2>&1 \
      && echo "   ✅ приглашён: $user" \
      || echo "   ⚠️  не удалось пригласить: $user"
  done
fi

echo ""
echo "✅ Готово:"
echo "   Организация: https://github.com/$ORG"
echo "   Репозиторий: https://github.com/$ORG/$REPO"
echo "   Участники:   https://github.com/orgs/$ORG/people"
