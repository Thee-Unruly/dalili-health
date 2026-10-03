"""Extract guideline PDFs into page-tagged chunks for the in-app index.

Usage:
    py tool/extract_guidelines.py <pdf> <doc_id> "<Document title>" [<pdf> <doc_id> "<title>" ...]

Writes assets/guidelines/<doc_id>.jsonl, one JSON object per chunk:
    {"doc": doc_id, "title": ..., "page": <PDF page, 1-based>, "section": ..., "text": ...}

`page` is the PDF page index (what a PDF viewer shows), not the printed
page number, so a citation can always be checked by opening the PDF.
Requires `pdftotext` (poppler) on PATH.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

CHUNK_WORDS = 180
OVERLAP_WORDS = 30
MIN_WORDS = 25  # skip near-empty pages (covers, blank pages)

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "guidelines"


def pdf_pages(pdf: Path) -> list[str]:
    out = subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", str(pdf), "-"],
        check=True,
        capture_output=True,
    ).stdout.decode("utf-8", errors="replace")
    return out.split("\f")


RUNNING_HEADS = {"imci handbook", "module", "contents"}


def guess_section(page_text: str) -> str:
    """First line that looks like a heading; empty if none found.

    Skips running heads like "18 ▼ IMCI HANDBOOK", strips page numbers from
    heads like "CHAPTER 7. COUGH OR DIFFICULT BREATHING ▼ 21", and joins a
    bare label ("CHAPTER 6", "Module 2:") with the title on the next line.
    """
    label = ""
    for raw in page_text.splitlines():
        line = re.sub(r"\s{2,}", " ", raw.replace("▼", " ")).strip()
        bare = re.fullmatch(r"\d*\s*((?:chapter|module|topic)\s*\d*[.:]?)", line, re.I)
        if bare:
            # A numberless "MODULE" is a running head, not a heading.
            if re.search(r"\d", bare.group(1)):
                label = bare.group(1).strip()
            continue
        line = re.sub(r"^\d+\s+|\s+\d+$", "", line).strip()
        if line.lower() in RUNNING_HEADS:
            continue
        if len(line) < 4 or len(line) > 90:
            continue
        if re.fullmatch(r"[\d\s.\-–—]+", line):  # page numbers, rules
            continue
        if sum(c.isalpha() for c in line) < 4:
            continue
        return f"{label} {line}".strip()
    return label


def clean(text: str) -> str:
    text = text.replace(" ", " ").replace("�", "")
    return re.sub(r"\s+", " ", text).strip()


def chunk_words(words: list[str]) -> list[str]:
    if len(words) <= CHUNK_WORDS:
        return [" ".join(words)]
    chunks, step = [], CHUNK_WORDS - OVERLAP_WORDS
    for start in range(0, len(words), step):
        part = words[start : start + CHUNK_WORDS]
        if len(part) < MIN_WORDS and chunks:
            break
        chunks.append(" ".join(part))
    return chunks


def extract(pdf: Path, doc_id: str, title: str) -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    with open(OUT_DIR / f"{doc_id}.jsonl", "w", encoding="utf-8") as f:
        for i, page in enumerate(pdf_pages(pdf), start=1):
            words = clean(page).split(" ")
            if len(words) < MIN_WORDS:
                continue
            section = guess_section(page)
            for text in chunk_words(words):
                row = {"doc": doc_id, "title": title, "page": i, "section": section, "text": text}
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                count += 1
    return count


def main(argv: list[str]) -> None:
    if len(argv) < 3 or len(argv) % 3:
        sys.exit(__doc__)
    for pdf, doc_id, title in zip(argv[0::3], argv[1::3], argv[2::3]):
        n = extract(Path(pdf), doc_id, title)
        print(f"{doc_id}: {n} chunks -> {OUT_DIR / (doc_id + '.jsonl')}")


if __name__ == "__main__":
    main(sys.argv[1:])
