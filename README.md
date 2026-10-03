# Dalili

**Offline, guideline-cited decision support for community health workers.**

A community health worker describes a sick child in plain words. Dalili answers
with an action (urgent referral, treat at clinic, home care, ask more, or out
of scope), a short explanation, and the guideline page it came from. Everything
runs on an Android phone with no network connection.

> Decision support for trained health workers. Not a diagnosis.

Built for the World Bank Group **Small AI for Development Hackathon 2026**
(health track).

## How it works

```
health worker's notes (English / Kiswahili)
  -> small on-device LLM extracts symptom fields (JSON, validated, retried)
  -> deterministic rules engine decides the action (WHO IMCI rules as data)
  -> guideline index retrieves the supporting passage (doc, section, PDF page)
  -> LLM explains the result in plain language, grounded in that passage
```

The model never makes the decision. The rules make it, the guideline backs it
up, and the model only reads and explains.

| Layer | Where |
|---|---|
| Triage screen, result and source cards | `lib/presentation/screens/triage/` |
| Triage service boundary | `lib/services/triage_service.dart` |
| Rules engine and safety gate (pure Dart) | `packages/dalili_triage/` |
| Cited guideline search (BM25, offline) | `lib/services/guideline_index.dart` |
| Guideline extraction from PDFs | `tool/extract_guidelines.py` |
| On-device model, downloads, RAG storage | [`denizen_ai`](https://github.com/Ubuntu-Edge/denizen-ai-sdk) SDK |
| Offline Audio (STT/TTS) | `lib/services/offline_audio_service.dart` |

App tabs: **Triage**, **Ask** (questions answered only from the guidelines,
with citations), **Guidelines**, **Settings** (model registry).

## Safety design

- Actions, never diagnoses. Every result shows its source page.
- Missing information produces follow-up questions instead of a guess.
- Inputs outside the guideline (age range or topic) are reported as out of
  scope.
- Outcomes use colour **and** an icon **and** a text label; touch targets are
  48dp or larger.

## Status

- [x] Triage UI with real service integration
- [x] Guideline extraction and cited search over WHO IMCI and the Kenya CHV
  handbook
- [x] Deterministic rules engine and safety gate, with tests
- [x] Foundational IMCI rule conditions encoded
- [x] Real triage pipeline on device
- [x] Offline voice input architecture (STT/TTS)

## Run

Requirements: Flutter 3.35+, an Android device (on-device inference is
Android-only), and the `denizen_ai` SDK checked out one level up (`../`).

```sh
flutter pub get
flutter test
flutter run            # on an Android device
```

Guideline text is not committed (copyright). Generate it from your own copies
of the PDFs; see [`assets/guidelines/README.md`](assets/guidelines/README.md).

Rules engine tests: `cd packages/dalili_triage && dart test`.
