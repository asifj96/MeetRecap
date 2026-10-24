# MeetRecap iOS — build plan

Native iOS replica of the Android app MeetRecap (`com.meetrecap.app`).

| | Path |
|---|---|
| Android reference (read only) | `/Users/muhammadasifjaved/AndroidStudioProjects/SmartTextSummarizer` |
| iOS project (write here) | `/Users/muhammadasifjaved/iOS` |
| Language reference | [The Swift Programming Language (6.4)](https://docs.swift.org/latest/documentation/the-swift-programming-language/) |
| App reference | [Develop in Swift](https://developer.apple.com/tutorials/develop-in-swift/welcome-to-develop-in-swift-tutorials) |

The Android app is the behavior specification. The Swift book decides how the language is written. Develop in Swift and Apple’s framework docs cover SwiftUI, SwiftData, URLSession, Vision, and TestFlight.

## Product

MeetRecap turns meeting notes or a transcript into a structured recap:

- `tldr` — 1–3 sentence summary
- `decisions` — list of decisions
- `actionItems` — `{ task, owner, due }`, owner and due optional
- `nextSteps` — list of next steps
- `followUpEmail` — a short ready-to-send email

Output languages: English, Arabic (`العربية`), Urdu (`اردو`). Arabic and Urdu are right-to-left.

Also required, matching Android: local history, open and delete a saved recap, copy and share, gallery and camera with on-device Latin OCR, and a hash cache so the same text is not sent twice.

## Stack

| Android | iOS |
|---|---|
| Kotlin | Swift 6 |
| Jetpack Compose | SwiftUI |
| ViewModel + StateFlow | `@Observable` class |
| Navigation Compose | `NavigationStack` |
| Hilt | Pass the repository in from the app entry |
| Coroutines + Flow | `async` / `await` |
| Retrofit + kotlinx.serialization | `URLSession` + `Codable` |
| Room | SwiftData |
| ML Kit Latin OCR | Vision `RecognizeTextRequest` |
| Share / process-text intents | Share sheet, then a Share Extension |
| `BuildConfig.PROXY_BASE_URL` | `.xcconfig`, gitignored |
| JUnit + MockK | Swift Testing or XCTest |

Minimum deployment: iOS 17. One Xcode app target named MeetRecap.

## Rules that must match Android

- Trimmed input length is 100…10,000 characters. Outside that range, generation fails with the invalid-input message.
- Title is the trimmed source text, cut at 50 characters, with `…` when the source is longer.
- `RecapLanguage` cases: English (`isRtl` false), Arabic and Urdu (`isRtl` true). Display names: `English`, `العربية`, `اردو`. Prompt instructions: `English`, `Arabic`, `Urdu`.
- Error cases and messages:

  | Case | Message |
  |---|---|
  | No internet | No internet connection. Check your network and try again. |
  | Timeout | The request timed out. Please try again. |
  | Rate limited | Too many requests. Please wait a moment and try again. |
  | Invalid input | Text must be between 100 and 10,000 characters. |
  | Invalid response | Received an unexpected response: {details} |
  | API error | Request failed ({code}): {details} |
  | Unknown | Something went wrong: {details} |

- Request: `POST {PROXY_BASE_URL}recap`. The worker adds `Authorization: Bearer <GROQ_API_KEY>` and forwards to Groq. The app never sends that header.
- Model and token cap stay `openai/gpt-oss-120b` and `1500`, as in `GroqApiService` and `PromptBuilder`.
- System prompt asks for one JSON object with exactly the five keys above, every text value in the selected language, empty array or empty string when a field has no content, and no commentary outside the JSON.
- `contentHash` is the cache key for a repeated transcript.
- Share text uses the same section order as Android: summary, decisions, action items (`owner` / `due` in parentheses), next steps, follow-up email.

## Do

- Read the Android files before writing the matching Swift type. Start with `MeetingRecap.kt`, `RecapLanguage.kt`, `AppError.kt`, `GenerateRecapUseCase.kt`, and `RecapRepository.kt`.
- Keep domain types as `struct` and `enum`. Use a `class` for the screen model, the URL client, and the SwiftData model.
- Follow the Swift book in this order: [A Swift Tour](https://docs.swift.org/latest/documentation/the-swift-programming-language/guidedtour), then The Basics, Strings, Collections, Control Flow, Functions, Closures, Enumerations, Structures and Classes, Properties, Methods, Initialization, Optional Chaining, Error Handling, Protocols, Extensions, Concurrency.
- Put `GROQ_API_KEY` only in the existing Cloudflare Worker. Put `PROXY_BASE_URL` in a gitignored `.xcconfig`.
- Log HTTP bodies in Debug only.
- Add camera and photo-library usage strings to Info.plist before opening the camera or the library.
- Prove each phase with something you can run: a test, then a real recap on the simulator, then history, then OCR, then TestFlight.
- Keep this Android repo unchanged while the iOS app is created under `/Users/muhammadasifjaved/iOS`.

## Don't

- Do not translate Kotlin syntax line by line. Compose, Hilt, Room, Retrofit, and ML Kit stay on Android.
- Do not put the Groq key in the app, Info.plist, xcconfig, git, or Firebase.
- Do not call `https://api.groq.com` from the app.
- Do not replace the worker with Apple Foundation Models or Image Playground. Those are a different product. Vision is only for Latin OCR.
- Do not use `IMPLEMENTATION_PLAN.md` to configure the API key. That file is the old assignment record.
- Do not change the JSON keys or the prompt contract. Android and iOS must accept the same worker response.
- Do not build the Share Extension, Firebase Remote Config, or App Store submission before a real recap is saved and reopened.
- Do not commit `PROXY_BASE_URL`, keystores, or secrets.
- Do not study the Swift Language Reference up front. Open it when a compiler message is about grammar or attributes.
- Do not spend a week on the visionOS chapters. This port is iPhone.

## Build order

### 1. Domain and a failing-input test

Swift book: Tour through Initialization, Optional Chaining, Error Handling.

Create `Domain` with `ActionItem`, `MeetingRecap`, `RecapLanguage`, `AppError`, and `GenerateRecap`. A fake repository returns one hardcoded recap. A test asserts that text shorter than 100 characters and longer than 10,000 characters throws `invalidInput`, and that a 100-character string is accepted.

Done when that test passes.

### 2. Repository protocol

Swift book: Protocols, Extensions, Access Control.

`RecapRepository`: `generateRecap(text:language:) async throws`, `history`, `recap(id:) async -> MeetingRecap?`, `delete(id:)`. Port `JsonSanitizer` and `HashUtil` next to the client, as on Android.

### 3. Live proxy

Swift book: Concurrency. Framework: URLSession and Codable.

`POST {proxy}/recap`, decode the five-key payload, map HTTP failures onto `AppError`. One generate request at a time.

Done when English, Arabic, and Urdu each return a recap from the existing worker.

### 4. Screens

Framework: SwiftUI, Observation, NavigationStack. Book chapter to open when `some View` appears: Opaque and Boxed Protocol Types. Book chapter for `@Observable`: Macros.

Screens match `MainScreen` and `HistoryScreen`: input, character count, language picker, generate, loading, recap sections, copy, share, history, delete, open a saved recap. Layout direction comes from `RecapLanguage.isRtl`. Screen fields match `MainUiState`: `inputText`, `selectedLanguage`, `isLoading`, `isScanning`, `currentRecap`, `errorMessage`.

### 5. History

Framework: SwiftData. Store the same fields as `MeetingRecapEntity`, including `contentHash`. List newest first, fetch by id, delete, and return a cached recap when the hash matches.

### 6. Camera, photos, Latin OCR

Framework: PhotosPicker, a small camera wrapper, Vision `RecognizeTextRequest` for Latin script. Extracted text prefills the input. `isScanning` shows the overlay.

### 7. Share, reachability, tests

Share text matches `MeetingRecap.toShareText()`. Reachability maps to `noInternet`. Add tests for the length rule, JSON sanitizing, and a fake repository. The Share Extension (Android `ACTION_SEND` and `PROCESS_TEXT`) is a second target after those pass.

### 8. TestFlight

Bundle id, icon, version, archive, TestFlight. A compiled proxy URL is enough. A later remote override may replace that URL only when the value is `https`, ends with `/`, and uses the same host.

## Suggested pace

About 6–8 part-time weeks: phases 1–2 in the first week, a live recap in week 2, both screens in week 3, history in week 4, OCR in week 5, share and tests in week 6, TestFlight after that.

## First agent instruction

Create the Xcode project at `/Users/muhammadasifjaved/iOS`. Read the Android app. Do not modify it. Implement phase 1 only, then stop.
