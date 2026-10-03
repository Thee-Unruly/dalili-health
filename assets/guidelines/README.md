# Guideline chunks

The `*.jsonl` files in this folder are generated, not committed: they contain
text extracted from copyrighted guideline PDFs (WHO, Kenya Ministry of Health).

Regenerate them from your own copies of the PDFs (needs `pdftotext`):

```sh
py tool/extract_guidelines.py \
  9789241506823_Chartbook_eng.pdf who_imci_chartbook_2014 "WHO IMCI Chart Booklet (2014)" \
  9241546441.pdf                  who_imci_handbook       "WHO IMCI Handbook" \
  CHV_handbook_PDF-F.pdf          kenya_chv_handbook      "Kenya CHV Handbook"
```

Each line: `{"doc", "title", "page", "section", "text"}`. `page` is the PDF page
index, so citations can be checked by opening the PDF at that page.
