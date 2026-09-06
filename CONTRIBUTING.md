# Contributing to Hozon

Thanks for taking the time to improve Hozon.

## Before you start

- Search existing issues before opening a duplicate.
- For a substantial feature or behavioral change, open an issue first so its scope and iPad interaction can be discussed.
- Keep pull requests focused. Unrelated cleanup belongs in a separate change.

## Development workflow

1. Fork the repository and create a branch from `main`.
2. Build the `Hozon` scheme for an iPad Simulator.
3. Add or update tests for behavior that can be exercised without live credentials.
4. Run the unit tests and a Release simulator build.
5. Open a pull request explaining the user-visible behavior and validation performed.

Use the setup commands in [README.md](README.md). Never commit API keys, provisioning profiles, certificates, `Config/Local.xcconfig`, or Xcode user data.

## Engineering conventions

- Prefer SwiftUI-native APIs and system components.
- Use async/await for asynchronous work.
- Keep state at its narrowest owner: local UI state in a view, feature state in an `@Observable` store, and shared mutable persistence behind an actor or service boundary.
- Keep business logic outside SwiftUI `body` implementations.
- Prefer small, explicit view types over large view files or unnecessary view-model layers.
- Preserve structured concurrency and cancellation.
- Treat URLs, link metadata, server messages, and credentials as private in logs.
- Avoid adding a package when the platform APIs are sufficient.

## Validation

At minimum, run:

```sh
xcodebuild build-for-testing \
  -project Hozon.xcodeproj \
  -scheme Hozon \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project Hozon.xcodeproj \
  -scheme Hozon \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

For UI changes, also verify the relevant loading, empty, error, light/dark appearance, Dynamic Type, and iPad size-class states.

## Conduct

Be respectful and constructive. Review the work rather than the person, assume good intent, and make room for contributors who are still learning the platform. Harassment and discriminatory behavior are not welcome.
