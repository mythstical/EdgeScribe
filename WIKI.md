# EdgeScribe Deep Wiki

## Project Overview
**EdgeScribe** is a privacy-first medical transcription and documentation assistant. It leverages a **Hybrid AI** architecture to ensure sensitive patient data (PII/PHI) never leaves the device in an unencrypted or identifiable format.

By combining on-device local AI (via the **Cactus SDK**) with powerful cloud-based LLMs, EdgeScribe achieves the "best of both worlds":
1.  **Privacy**: Zero-trust architecture where PII is redacted locally.
2.  **Power**: Cloud LLMs are used only for non-sensitive tasks (like SOAP note generation on redacted text).
3.  **Speed**: Local inference for real-time feedback and redaction.

---

## Hybrid AI Architecture

The core philosophy of EdgeScribe is **"Privacy First, Cloud Power"**.

### The "Round Trip" Privacy Pipeline
To safely use cloud AI for medical documentation without violating HIPAA/GDPR, EdgeScribe implements a reversible redaction pipeline:

1.  **Local Redaction (On-Device)**:
    *   Raw transcript is processed locally.
    *   PII (names, dates, locations) is identified and replaced with unique placeholders (e.g., `{{PERSON_1}}`, `{{DATE_0}}`).
    *   A secure mapping key is generated and stored *only* in the device's secure storage.

2.  **Cloud Processing (Safe)**:
    *   The *redacted* text is sent to a cloud LLM (e.g., OpenRouter/Anthropic/OpenAI).
    *   The cloud model generates a SOAP note or summary using the redacted text. It never sees "John Doe", only `{{PERSON_1}}`.

3.  **Local Restoration (Re-Identification)**:
    *   The structured response returns to the device.
    *   EdgeScribe uses the secure mapping key to swap the placeholders back to the original values.
    *   The user sees the fully restored, accurate note.

---

## The Cactus SDK Integration
**Cactus** is the engine powering the local intelligence of EdgeScribe. It enables running quantized Large Language Models (LLMs) directly on the user's device (Android/iOS).

### Model Configuration
*   **Model**: `qwen3-0.6` (Qwen 2.5 0.6B Instruct)
*   **Context Size**: 2048 tokens
*   **Role**: Entity extraction and context-aware PII detection.

### `CactusModelService`
Located in `lib/services/cactus_model_service.dart`, this is a singleton service that manages the lifecycle of the local model:
*   **Initialization**: Downloads and loads the model into RAM on app startup.
*   **Persistence**: Keeps the model resident to ensure zero-latency for subsequent calls.
*   **Resource Management**: Provides methods to unload the model when the app is backgrounded or closed to free up system resources.

---

## Deep Dive: The Redaction Pipeline
The `MedicalRedactorService` (`lib/services/medical_redactor_service.dart`) implements a sophisticated **"Extract & Locate"** architecture. This is superior to simple "Ask the LLM to rewrite this" approaches, which are prone to hallucinations and data loss.

### Layer 1: The Rule Engine (Deterministic)
Before involving the AI, we use high-precision Regex patterns to catch structured PII. This is fast, cheap, and 100% accurate for known formats.
*   **Targets**: SSNs, Email addresses, Phone numbers, Dates, ZIP codes.
*   **Action**: Immediate replacement with tags like `[SSN]`, `[EMAIL]`.

### Layer 2: The Local LLM (Contextual)
Structured rules fail on unstructured entities like names ("Dr. House") or facility names ("Princeton-Plainsboro Hospital"). This is where Cactus comes in.
*   **Input**: The text (already processed by Layer 1).
*   **Task**: "List ONLY the Person Names and Organization Names in the text."
*   **Output**: A structured list (e.g., `Gregory House | PERSON`).
*   **Why this way?**: Asking a small 0.6B model to *rewrite* a paragraph often leads to it summarizing or dropping sentences. Asking it to simply *list* entities is a much easier task that it performs with high accuracy.

### Layer 3: Alignment & Validation (The Safety Net)
This is the critical step that prevents "hallucinations" (the AI inventing names that aren't there).
1.  **Verification**: The code takes the list from Layer 2 and searches for those exact strings in the original text.
2.  **Anti-Hallucination**: If the LLM claims "Batman" is in the text, but the text doesn't contain "Batman", the entity is discarded.
3.  **Redaction**: Validated entities are located and redacted in the text.

---

## Technical Implementation Details

### Reversible Redaction Logic
To support the "Round Trip" pipeline, the service doesn't just delete PII; it maps it.

```dart
// Concept of Reversible Redaction
Map<String, String> mapping = {
  "{{PERSON_0}}": "Alice Smith",
  "{{ORG_0}}": "Mayo Clinic"
};

String redacted = "Patient {{PERSON_0}} visited {{ORG_0}}.";
// Sent to Cloud -> Cloud returns: "Assessment for {{PERSON_0}} at {{ORG_0}}..."
// Local Restore -> "Assessment for Alice Smith at Mayo Clinic..."
```

### Performance Considerations
*   **Initialization**: The model takes a few seconds to load. We initialize it in `main.dart` to ensure it's ready by the time the user starts recording.
*   **Inference Speed**: On modern mobile chipsets, the 0.6B model runs inference in <1 second for typical paragraph-length segments.
*   **Memory Footprint**: The quantized model requires ~500MB - 1GB of RAM, which is manageable for modern devices but requires careful lifecycle management (unloading when not in use).

## Future Roadmap
*   **On-Device ASR**: Currently using platform speech recognition. Future plans involve integrating Whisper via Cactus for fully offline transcription.
*   **Larger Models**: As mobile hardware improves, upgrading to 1.5B or 3B parameter models for better nuance in entity extraction.
