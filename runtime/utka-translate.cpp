// utka-translate: перевод en<->ru полностью локально, без Apple, Google
// или любого другого стороннего сервиса. Движок — CTranslate2 (MIT),
// токенизация — SentencePiece (Apache 2.0), модели — OPUS-MT (CC BY 4.0).
//
// Использование:
//   utka-translate --dir <папка с моделями> --from en --to ru "текст"
//
// В <папке с моделями> ожидаются подпапки en-ru/ и ru-en/, в каждой —
// ct2/ (файлы CTranslate2: model.bin, config.json, shared_vocabulary.json)
// и source.spm/target.spm (токенизаторы SentencePiece).
#include <ctranslate2/translator.h>
#include <sentencepiece_processor.h>

#include <iostream>
#include <string>
#include <vector>

namespace {

void usage(const char* prog) {
    std::cerr << "Использование: " << prog
              << " --dir <папка с моделями> --from en --to ru \"текст\"\n";
}

std::string joinPath(const std::string& a, const std::string& b) {
    if (!a.empty() && a.back() == '/') return a + b;
    return a + "/" + b;
}

}  // namespace

int main(int argc, char** argv) {
    std::string modelsDir, from, to, text;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--dir" && i + 1 < argc) {
            modelsDir = argv[++i];
        } else if (arg == "--from" && i + 1 < argc) {
            from = argv[++i];
        } else if (arg == "--to" && i + 1 < argc) {
            to = argv[++i];
        } else if (arg == "-h" || arg == "--help") {
            usage(argv[0]);
            return 0;
        } else {
            text = arg;
        }
    }
    if (modelsDir.empty() || from.empty() || to.empty() || text.empty()) {
        usage(argv[0]);
        return 2;
    }

    const std::string pair = from + "-" + to;
    const std::string pairDir = joinPath(modelsDir, pair);

    sentencepiece::SentencePieceProcessor sourceTokenizer;
    auto status = sourceTokenizer.Load(joinPath(pairDir, "source.spm"));
    if (!status.ok()) {
        std::cerr << "Не удалось открыть source.spm: " << status.ToString() << "\n";
        return 1;
    }
    sentencepiece::SentencePieceProcessor targetTokenizer;
    status = targetTokenizer.Load(joinPath(pairDir, "target.spm"));
    if (!status.ok()) {
        std::cerr << "Не удалось открыть target.spm: " << status.ToString() << "\n";
        return 1;
    }

    std::vector<std::string> pieces;
    status = sourceTokenizer.Encode(text, &pieces);
    if (!status.ok()) {
        std::cerr << "Не удалось разбить текст на токены: " << status.ToString() << "\n";
        return 1;
    }

    try {
        ctranslate2::Translator translator(joinPath(pairDir, "ct2"));
        std::vector<std::vector<std::string>> batch = {pieces};
        auto results = translator.translate_batch(batch);
        const auto& outputTokens = results.front().output();

        std::string translated;
        status = targetTokenizer.Decode(outputTokens, &translated);
        if (!status.ok()) {
            std::cerr << "Не удалось собрать перевод из токенов: " << status.ToString() << "\n";
            return 1;
        }
        std::cout << translated << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Ошибка перевода: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
