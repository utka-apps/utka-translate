# utka-translate

Офлайн-движок перевода английский↔русский для Утки: не зависит ни от Apple, ни от Google, ни от какого-либо стороннего сервиса. Один раз скачивается и дальше работает полностью на этом Маке.

## Почему этот репозиторий появился

В части регионов (похоже, из-за требований ЕС) Apple не даёт скачать офлайн-модель перевода в принципе — ни через приложение «Переводчик», ни через системные настройки, ни через какой-либо API. У Утки был запасной путь через интернет-сервис без ключа (mymemory.translated.net), но это означает, что переводимый текст уходит наружу открытым текстом. Этот репозиторий — третий, независимый путь: свой движок и своя модель, целиком под нашим контролем.

## Из чего это сделано

- **Модели** — открытые модели [OPUS-MT](https://github.com/Helsinki-NLP/OPUS-MT-train) проекта Helsinki-NLP, лицензия **CC BY 4.0** (обязательна атрибуция, коммерческое и любое другое использование разрешено).
- **Движок** — [CTranslate2](https://github.com/OpenNMT/CTranslate2), быстрая C++-библиотека инференса для трансформерных моделей перевода, лицензия MIT.
- Модели сконвертированы в формат CTranslate2 со сжатием int8 — около 80 МБ на направление, 160 МБ на обе стороны (en→ru и ru→en).

## Статус

- [x] Модели скачаны и сконвертированы, перевод в обе стороны проверен вручную (`scripts/translate-smoke-test.py`).
- [x] Модели опубликованы в [Releases](../../releases) этого репозитория.
- [x] **Нативный рантайм под macOS (arm64).** Свой CLI `utka-translate` (C++) на CTranslate2 + SentencePiece, без Python. Все зависимости (.dylib CTranslate2/SentencePiece/Abseil) упакованы рядом через `@rpath`, без единого абсолютного пути на Homebrew — проверено в окружении без Homebrew. Опубликовано в [Releases](../../releases/tag/v0.1.0-runtime-macos-arm64).
- [ ] Подключение к самой Утке (`Translator.swift`) как приоритетного способа перевода, перед Apple и перед интернет-запасным.

## Как воспроизвести модели самому

```bash
pip3 install ctranslate2 sentencepiece
bash scripts/prepare-models.sh
python3 scripts/translate-smoke-test.py "Hello, how are you today?" en ru
```

## Лицензии и атрибуция

- Модели: OPUS-MT (Helsinki-NLP), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Обучены на открытом корпусе [OPUS](https://opus.nlpl.eu/).
- Движок: [CTranslate2](https://github.com/OpenNMT/CTranslate2), MIT.
- Код в этом репозитории: MIT, как и в основном репозитории Утки.

## Как собрать нативный рантайм самому

Нужны Command Line Tools, `cmake` и Homebrew (`brew install cmake sentencepiece abseil`) — но только на машине, где собираешь. Утке для запуска готового бинарника из Releases ничего из этого не нужно.

```bash
git clone --depth 1 --recursive https://github.com/OpenNMT/CTranslate2.git ctranslate2-src
cd ctranslate2-src && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DWITH_ACCELERATE=ON -DOPENMP_RUNTIME=NONE -DBUILD_CLI=OFF -DCMAKE_OSX_ARCHITECTURES=arm64 ..
cmake --build . --config Release -j$(sysctl -n hw.ncpu)
cd ../..

clang++ -std=c++17 -O2 \
  -I ctranslate2-src/include -I $(brew --prefix sentencepiece)/include -I $(brew --prefix abseil)/include \
  -L ctranslate2-src/build -lctranslate2 \
  -L $(brew --prefix sentencepiece)/lib -lsentencepiece \
  -L $(brew --prefix abseil)/lib -labsl_status -labsl_statusor -labsl_cord -labsl_strings -labsl_base -labsl_raw_logging_internal \
  -Wl,-rpath,@executable_path/lib \
  runtime/utka-translate.cpp -o runtime/utka-translate

cp ctranslate2-src/build/libctranslate2*.dylib runtime/
bash scripts/bundle-dylibs.sh runtime/utka-translate
codesign --force -s - runtime/lib/*.dylib runtime/utka-translate
```

Результат — `runtime/utka-translate` и `runtime/lib/*.dylib` рядом: самодостаточная пара, без Homebrew и Python на машине, где будет запускаться.
