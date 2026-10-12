#!/usr/bin/env bash
# Rebuilds PredictiveEngine/Sources/PredictiveEngine/Resources/en.sdict from
# public word-frequency and bigram lists. The compiled file is committed; run
# this only when changing the corpus or the format.
#
# Sources (see PredictiveEngine/Sources/PredictiveEngine/Resources/LICENSES.md):
#   - hermitdave/FrequencyWords en_50k.txt   (OpenSubtitles 2018, CC-BY-SA 4.0)
#   - norvig.com/ngrams count_2w.txt         (Google Web Trillion Word Corpus)
set -euo pipefail

cd "$(dirname "$0")/../PredictiveEngine"
corpus=corpus
mkdir -p "$corpus"

fetch() {
  local url=$1 dest=$2
  if [ ! -s "$dest" ]; then
    echo "downloading $url"
    curl -sSL --fail -o "$dest" "$url"
  fi
}
fetch https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt "$corpus/en_50k.txt"
fetch https://norvig.com/ngrams/count_2w.txt "$corpus/count_2w.txt"

swift run -c release sdict-compile \
  --words "$corpus/en_50k.txt" \
  --bigrams "$corpus/count_2w.txt" \
  --out Sources/PredictiveEngine/Resources/en.sdict \
  "$@"
