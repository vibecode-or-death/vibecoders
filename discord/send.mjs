#!/usr/bin/env node
// Публикует готовые embed-посты в Discord через вебхук.
// Node.js 18+ (встроенный fetch), без зависимостей.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const POSTS_FILE = path.join(ROOT, 'posts.json');
const ENV_FILE = path.join(ROOT, '.env');

function loadEnv() {
  if (!fs.existsSync(ENV_FILE)) return {};
  const out = {};
  for (const line of fs.readFileSync(ENV_FILE, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    out[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
  }
  return out;
}

const env = { ...loadEnv(), ...process.env };
const webhook = env.DISCORD_WEBHOOK_URL;
const args = process.argv.slice(2);

const posts = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));

if (args.includes('--list')) {
  posts.forEach((post, i) => console.log(`[${i + 1}] ${post.name}  → #${post.channel}`));
  process.exit(0);
}

if (!webhook) {
  console.error('❌ Не задан DISCORD_WEBHOOK_URL. Создай .env из .env.example и вставь URL вебхука.');
  process.exit(1);
}

const dry = args.includes('--dry');
const selected = args.filter((a) => /^\d+$/.test(a)).map((n) => Number(n) - 1);
const targets = selected.length ? selected.map((i) => posts[i]).filter(Boolean) : posts;

if (!targets.length) {
  console.error('❌ Не выбрано ни одного поста. Проверь номера: node send.mjs --list');
  process.exit(1);
}

console.log(`${dry ? '🔍 DRY RUN' : '📤 Публикуем'}: ${targets.map((p) => p.name).join(', ')}\n`);

for (const post of targets) {
  if (dry) {
    console.log(`--- [${post.name}] ---`);
    console.log(JSON.stringify(post.payload, null, 2));
    continue;
  }

  const res = await fetch(webhook, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(post.payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`❌ ${post.name}: HTTP ${res.status} — ${text}`);
    process.exitCode = 1;
    continue;
  }

  const data = await res.json();
  const link = `https://discord.com/channels/${data.guild_id}/${data.channel_id}/${data.id}`;
  console.log(`✅ ${post.name}\n   ${link}\n   → правый клик по сообщению → Закрепить сообщение\n`);
  await new Promise((resolve) => setTimeout(resolve, 600));
}
