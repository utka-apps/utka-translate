#!/bin/bash
# Скачивает открытые модели OPUS-MT (Helsinki-NLP, лицензия CC BY 4.0) и
# конвертирует их в формат CTranslate2 со сжатием int8. Результат — то,
# что публикуется в Releases этого репозитория и вшивается в Утку.
#
# Нужен python3 с пакетами ctranslate2 и sentencepiece:
#   pip3 install ctranslate2 sentencepiece
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
CT2="$ROOT/ct2"

EN_RU_URL="https://object.pouta.csc.fi/OPUS-MT-models/en-ru/opus-2020-02-11.zip"
RU_EN_URL="https://object.pouta.csc.fi/OPUS-MT-models/ru-en/opus-2020-02-26.zip"

download() {
  local url="$1" dir="$2"
  mkdir -p "$dir"
  if [ ! -f "$dir/decoder.yml" ]; then
    echo "скачиваю $url"
    curl -sL --retry 3 -o "$dir/model.zip" "$url"
    unzip -oq "$dir/model.zip" -d "$dir"
  fi
}

download "$EN_RU_URL" "$SRC/en-ru"
download "$RU_EN_URL" "$SRC/ru-en"

python3 - <<PY
from ctranslate2.converters import OpusMTConverter
import os

for pair in ("en-ru", "ru-en"):
    out = os.path.join("$CT2", pair)
    if os.path.isdir(out):
        print(pair, "уже сконвертирован, пропускаю")
        continue
    print("конвертирую", pair)
    OpusMTConverter(os.path.join("$SRC", pair)).convert(out, quantization="int8")
PY

echo "готово: $CT2/en-ru и $CT2/ru-en"
