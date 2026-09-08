# ClassSync — Offline-First Classroom Assessment Platform

ClassSync enables teachers to create and conduct quizzes entirely peer-to-peer (no active internet or shared Wi-Fi required) using Bluetooth and Nearby Connections, inspired by **Delay Tolerant Networking (DTN)** principles: every device functions autonomously and syncs opportunistically whenever a connection is established.

---

## 🔒 Cryptographic Security Architecture

Security in ClassSync is built as a core pillar:
1. **Trust Bootstrapping**: At term start, student **Ed25519** public keys are registered with the teacher's roster ahead of time.
2. **Ephemeral Pairing**: Session QR codes encode only `session_id` and an ephemeral **AES-256-GCM** key — student private identities are never broadcast in plaintext.
3. **Signed Packages & Submissions**:
   - Every **Quiz** package is digitally signed by the teacher's Ed25519 private key before distribution.
   - Every student **Submission** is digitally signed by the student's Ed25519 private key before transmission.
   - Both sides cryptographically verify signatures before accepting payloads.
4. **Incremental Answer Hash Chains**:
   - `hash_chain_link = SHA-256(previous_hash + question_id + response + timestamp)`.
   - Calculated incrementally on every answer save in SQLite.
   - Any mid-quiz answer tampering breaks the chain and is detected at the teacher verification gate.
5. **Deterministic Submission Deduplication**:
   - `submission_id = SHA-256("sub:" + student_id + ":" + session_id + ":" + device_id)`.
   - Retries or reconnect duplicates collapse cleanly into one SQLite record with zero data loss and zero duplicates.

---

## 📱 Tech Stack & Target Platforms

- **Flutter / Dart**: Monorepo powering **Teacher App** (Desktop/Tablet) and **Student App** (Mobile).
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`).
- **Local Storage**: `sqflite` (Android/iOS) and `sqflite_common_ffi` (Desktop & Unit tests).
- **Cryptography**: `cryptography` package (Ed25519, AES-256-GCM, SHA-256).
- **QR Codes**: `qr_flutter` (generator) + `mobile_scanner` (scanner).
- **P2P Transport**: `nearby_connections` (Android).
- **Cloud Backend (Optional / Phase 7)**: FastAPI + PostgreSQL + SQLAlchemy.

### 🍎 iOS Compatibility Notice
Google Nearby Connections operates natively on Android via Google Play Services. On iOS, Google Nearby Connections does not support offline Wi-Fi Direct star topology due to Apple sandbox constraints. For iOS production deployments, ClassSync uses Apple Multipeer Connectivity (`flutter_nearby_connections`). The core P2P interface (`P2PTransport`) abstracts this transport cleanly.

---

## 🗄️ Database Schema

Implemented with SQLite table mappings and foreign key integrity:
- `teachers` (`teacher_id`, `name`, `public_key`, `private_key_hash`)
- `students` (`student_id`, `name`, `public_key`, `class_id`)
- `devices` (`device_id`, `student_id` FK, `platform`)
- `quizzes` (`quiz_id`, `teacher_id` FK, `title`, `time_limit`, `created_at`, `signature`)
- `questions` (`question_id`, `quiz_id` FK, `type`, `body`, `options`, `correct_answer`, `marks`, `explanation`)
- `sessions` (`session_id`, `quiz_id` FK, `teacher_id` FK, `qr_token`, `started_at`, `status`)
- `attendance` (`attendance_id`, `session_id` FK, `student_id` FK, `marked_at`)
- `submissions` (`submission_id`, `session_id` FK, `student_id` FK, `device_id` FK, `start_ts`, `submit_ts`, `student_signature`, `sync_status`, `score`, `total_possible_marks`, `status`, `is_signature_verified`, `is_hash_chain_verified`)
- `answers` (`answer_id`, `submission_id` FK, `question_id` FK, `response`, `hash_chain_link`)

---

## 🧪 Testing & Verification

### Running the Test Suite
```powershell
# Run all unit, cryptographic, flow, and resilience tests
flutter test

# Run individual test modules:
flutter test test/crypto_test.dart            # Ed25519, AES-GCM, Hash Chains, Deterministic IDs
flutter test test/database_test.dart          # SQLite Schema, DAOs, Relational constraints
flutter test test/quiz_flow_test.dart         # Local quiz taking, autosave, submission signing
flutter test test/resilience_harness_test.dart # Phase 6 Multi-Device DTN Resilience Harness (5 devices)
```

### Phase 6: Multi-Device DTN Resilience Test Harness
Proves the core offline-first claims:
1. 1 Teacher node and 5 Student devices join an active session.
2. Connectivity is severed mid-quiz for 2 devices (simulating airplane mode / stepping out of range).
3. Disconnected students continue answering offline with local SQLite autosave & SHA-256 hash chaining.
4. Dropped devices reconnect at staggered times and flush queued submissions.
5. Duplicate transmission syncs collapse into 1 record using deterministic `submission_id`.
6. Assertions confirm **zero data loss**, **zero duplicate submissions**, and **100% cryptographic verification pass rate**.

---

## ☁️ Optional Cloud Sync Backend (Phase 7)

Located in `backend/`:

### Starting the FastAPI Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

- Endpoint `POST /api/sync/session`: Accepts synchronized session batches from Teacher devices.
- In Teacher App: Tap **"Sync to Cloud"** on completed sessions to upload verified results.
