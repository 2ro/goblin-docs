#!/usr/bin/env bash
# build.sh — runs ON THE SERVER to (re)build docs.goblin.st from source.
#
# Unlike goblin.st (whose webroot is the git tree and needs no build), the docs
# are mdBook source: this pulls the source tree and renders it into the webroot.
#
# Wire it into the same deploy-hook mechanism goblin.st uses, so a push to
# git.us-ea.st/GRIN/goblin-docs triggers it. Manual run: ./build.sh
set -euo pipefail

SRC="${DOCS_SRC:-/opt/goblin/docs-src}"     # git working tree (markdown source)
OUT="${DOCS_OUT:-/opt/goblin/www-docs}"     # nginx docroot (built static site)
BRANCH="${DOCS_BRANCH:-main}"

echo "==> pulling $SRC ($BRANCH)"
git -C "$SRC" pull --ff-only origin "$BRANCH"

echo "==> building with mdbook → $OUT"
# mdbook writes to book.toml's build dir; -d overrides it to the live webroot.
mdbook build "$SRC" -d "$OUT"

echo "==> done: $(find "$OUT" -name '*.html' | wc -l) pages"
