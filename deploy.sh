#!/usr/bin/env bash
# Publish this folder to GitHub Pages at www.arif.one
# Needs GITHUB_TOKEN (classic PAT with "repo" scope) in the environment.
set -euo pipefail
cd "$(dirname "$0")"
REPO="${REPO:-arif-one}"; DOMAIN="www.arif.one"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
api(){ curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"; }

USER=$(api https://api.github.com/user | python3 -c 'import sys,json;print(json.load(sys.stdin)["login"])')
echo "GitHub user: $USER"

code=$(api -o /tmp/repo.json -w '%{http_code}' -X POST https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO\",\"description\":\"Personal site - www.arif.one\",\"homepage\":\"https://$DOMAIN\",\"private\":false,\"has_wiki\":false,\"has_projects\":false}")
case $code in 201) echo "Repo created";; 422) echo "Repo already exists, reusing";; *) echo "Repo create failed ($code)"; cat /tmp/repo.json; exit 1;; esac

[ -d .git ] || git init -q -b main
git add -A
git -c user.name="Arif Tak" -c user.email="arif.tak@gmail.com" commit -qm "Publish site $(date -u +%F)" || echo "Nothing new to commit"
git push -q -f "https://x-access-token:${GITHUB_TOKEN}@github.com/${USER}/${REPO}.git" main
echo "Pushed to github.com/$USER/$REPO"

code=$(api -o /tmp/pages.json -w '%{http_code}' -X POST "https://api.github.com/repos/$USER/$REPO/pages" \
  -d '{"build_type":"legacy","source":{"branch":"main","path":"/"}}')
case $code in 201) echo "Pages enabled";; 409) echo "Pages already enabled";; *) echo "Pages enable failed ($code)"; cat /tmp/pages.json; exit 1;; esac

api -o /dev/null -X PUT "https://api.github.com/repos/$USER/$REPO/pages" -d "{\"cname\":\"$DOMAIN\"}"
echo "Custom domain set to $DOMAIN"
echo "Default URL: https://$USER.github.io/$REPO/"
# After DNS resolves and the certificate is issued, enforce HTTPS:
#   api -X PUT https://api.github.com/repos/$USER/$REPO/pages -d '{"https_enforced":true}'
