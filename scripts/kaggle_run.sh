#!/usr/bin/env bash
# Run a local notebook on Kaggle (competition data attached) and pull back its outputs.
#
# Usage: scripts/kaggle_run.sh notebooks/01_eda.ipynb [--gpu]
#
# Requires: `pip install kaggle` and an API token in ~/.kaggle/kaggle.json
# (kaggle.com -> Settings -> API -> Create New Token).
set -euo pipefail

COMPETITION="rsna-knee-abnormality-detection"
NB="${1:?usage: $0 path/to/notebook.ipynb [--gpu]}"
GPU=false; [[ "${2:-}" == "--gpu" ]] && GPU=true

USER_NAME="${KAGGLE_USERNAME:-$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.kaggle/kaggle.json")))["username"])')}"
NAME="$(basename "$NB" .ipynb)"
SLUG="rsna-knee-$(echo "$NAME" | tr '[:upper:]_' '[:lower:]-')"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.kaggle_build/$SLUG"
OUT="$ROOT/outputs/$NAME"

rm -rf "$BUILD"; mkdir -p "$BUILD" "$OUT"
cp "$NB" "$BUILD/$NAME.ipynb"
cat > "$BUILD/kernel-metadata.json" <<JSON
{
  "id": "$USER_NAME/$SLUG",
  "title": "$SLUG",
  "code_file": "$NAME.ipynb",
  "language": "python",
  "kernel_type": "notebook",
  "is_private": true,
  "enable_gpu": $GPU,
  "enable_internet": false,
  "dataset_sources": [],
  "competition_sources": ["$COMPETITION"],
  "kernel_sources": []
}
JSON

echo ">> Pushing $NB as $USER_NAME/$SLUG (gpu=$GPU)"
kaggle kernels push -p "$BUILD"

echo ">> Waiting for the run to finish (Ctrl+C is safe; the run continues on Kaggle)"
while true; do
  STATUS="$(kaggle kernels status "$USER_NAME/$SLUG" 2>&1 || true)"
  echo "   $(date +%H:%M:%S) $STATUS"
  case "$STATUS" in
    *COMPLETE*|*complete*) break ;;
    *ERROR*|*error*|*CANCEL*|*cancel*) echo ">> Run failed; fetching log"; break ;;
  esac
  sleep 30
done

echo ">> Downloading outputs to $OUT"
kaggle kernels output "$USER_NAME/$SLUG" -p "$OUT"
# The executed notebook (with cell outputs) comes back too; open it to see results.
ls -la "$OUT"
