#!/usr/bin/env python3
"""Проверка, что сконвертированные модели реально переводят.
Использование: python3 scripts/translate-smoke-test.py "Hello, how are you?" en ru
"""
import sys
import ctranslate2
import sentencepiece as spm


def translate(root: str, pair: str, text: str) -> str:
    src = spm.SentencePieceProcessor(model_file=f"{root}/src/{pair}/source.spm")
    tgt = spm.SentencePieceProcessor(model_file=f"{root}/src/{pair}/target.spm")
    translator = ctranslate2.Translator(f"{root}/ct2/{pair}")
    tokens = src.encode(text, out_type=str)
    result = translator.translate_batch([tokens])
    return tgt.decode(result[0].hypotheses[0])


if __name__ == "__main__":
    text = sys.argv[1] if len(sys.argv) > 1 else "Hello, how are you today?"
    source = sys.argv[2] if len(sys.argv) > 2 else "en"
    target = sys.argv[3] if len(sys.argv) > 3 else "ru"
    pair = f"{source}-{target}"
    root = "."
    print(translate(root, pair, text))
