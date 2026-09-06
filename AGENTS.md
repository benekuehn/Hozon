# Repository Instructions

## Scope

Hozon is a native, iPad-only SwiftUI client for Shiori. The minimum deployment target is iPadOS 18.

## Implementation principles

- Prefer SwiftUI-native patterns and Apple frameworks.
- Prefer async/await and structured concurrency over Combine.
- Keep local presentation state in views and feature state in focused `@Observable` stores.
- Pass feature dependencies explicitly. Assemble live dependencies in `AppEnv`.
- Keep persistence and networking behind protocols or actors where isolation or testing benefits from the boundary.
- Split view files when they contain multiple independently meaningful screens.
- Do not introduce architecture, dependencies, or abstractions without a concrete need.
- Preserve cancellation and mark private data appropriately when using `Logger`.

## Repository safety

- Never commit API keys, signing certificates, provisioning profiles, or `Config/Local.xcconfig`.
- Do not replace public configuration defaults with a contributor's Apple team or bundle identifiers.
- Keep app and Action-extension App Group and Keychain settings aligned.

## Validation

For production changes, run a Debug build-for-testing and a Release simulator build with signing disabled. Run unit tests on an available iPad Simulator. Keep changes warning-free and add focused tests for changed domain behavior.
