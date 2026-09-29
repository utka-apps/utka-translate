#!/bin/bash
# Копирует все нужные .dylib рядом с бинарником и переписывает пути так,
# чтобы результат работал на любом Маке, где нет Homebrew.
set -euo pipefail
BIN="$1"
DIR="$(dirname "$BIN")"
LIB="$DIR/lib"
mkdir -p "$LIB"

SEARCH_ROOTS=("$(brew --prefix abseil)/lib" "$(brew --prefix sentencepiece)/lib")

seen=()
queue=("$BIN")

is_system() {
  case "$1" in
    /usr/lib/*|/System/*) return 0 ;;
    *) return 1 ;;
  esac
}

already_seen() {
  local needle="$1"
  for x in "${seen[@]:-}"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

while [ "${#queue[@]}" -gt 0 ]; do
  current="${queue[0]}"
  queue=("${queue[@]:1}")
  if already_seen "$current"; then continue; fi
  seen+=("$current")

  deps=$(otool -L "$current" | tail -n +2 | awk '{print $1}')
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    if is_system "$dep"; then continue; fi
    name="$(basename "$dep")"
    dest="$LIB/$name"
    if [ ! -f "$dest" ]; then
      # dep может уже быть @rpath/... (собственная либа, как libctranslate2) —
      # тогда берём файл рядом со сборкой ctranslate2.
      if [[ "$dep" == @rpath/* || "$dep" == @loader_path/* ]]; then
        src="$(find "$(dirname "$BIN")/.." "${SEARCH_ROOTS[@]}" -maxdepth 3 -name "$name" 2>/dev/null | head -1)"
      else
        src="$dep"
      fi
      [ -z "${src:-}" ] && { echo "не нашёл файл для $dep" >&2; continue; }
      cp -L "$src" "$dest"
      chmod u+w "$dest"
      install_name_tool -id "@rpath/$name" "$dest"
    fi
    if [[ "$dep" != "@rpath/$name" ]]; then
      install_name_tool -change "$dep" "@rpath/$name" "$current" 2>/dev/null || true
    fi
    queue+=("$dest")
  done <<< "$deps"
done

echo "готово: $LIB"
ls -la "$LIB"
