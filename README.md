# Hozon

<p align="center">
  <img src="Hozon/Assets.xcassets/AppIcon.appiconset/Group%205.png" width="128" height="128" alt="Hozon app icon">
</p>

Hozon is a native iPadOS client for [Shiori](https://www.shiori.sh), built with SwiftUI. It provides an iPad-focused inbox for saved links, feed subscriptions, a native article reader, and a Share action for saving links from other apps.

> [!NOTE]
> Hozon is in early development. Data models and setup steps may change before the first stable release.

## Features

- Inbox, archive, and trash views with local caching
- RSS and Atom feed subscriptions
- Native SwiftUI article reader backed by an isolated WebKit extractor
- Share action with direct delivery and a durable retry queue
- API-key storage in the Keychain shared with the app extension
- Adaptive iPad sidebar navigation, loading states, and SwiftUI previews

## Requirements

- Xcode 16 or later with the iOS 18 SDK
- iPadOS 18 or later
- A Shiori account and API key

The project has no third-party package dependencies.

## Build for Simulator

Clone the repository and open `Hozon.xcodeproj` in Xcode, or build from Terminal:

```sh
git clone https://github.com/benekuehn/Hozon.git
cd Hozon
xcodebuild build \
  -project Hozon.xcodeproj \
  -scheme Hozon \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Launch the app and enter the API key from your Shiori account. The key is stored in the device Keychain; it is not written to the repository or the link cache.

## Run on an iPad

Device builds require identifiers owned by your Apple Developer team:

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Set `HOZON_DEVELOPMENT_TEAM` and `HOZON_BUNDLE_IDENTIFIER` in the local file.
3. Register the resulting app and Action-extension bundle identifiers in your developer account.
4. Register the App Group `group.<your bundle identifier>` for both targets and enable Keychain Sharing.
5. Open the project once in Xcode and allow automatic signing to create the provisioning profiles.

`Config/Local.xcconfig` is ignored by Git. With one paired, booted physical iPad connected, the repository also provides:

```sh
./scripts/deploy-ipad.sh
```

Use `./scripts/deploy-ipad.sh --help` for device-selection options.

## Tests

Choose an installed iPad Simulator name and run:

```sh
xcodebuild test \
  -project Hozon.xcodeproj \
  -scheme Hozon \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

Pull requests and changes to `main` are also built and tested by GitHub Actions.

## Architecture

Hozon deliberately uses a small, native structure:

```text
Hozon/
├── App/                  App entry point, environment, theme, and credentials
├── Core/                 Browser and native-reader infrastructure
├── Features/
│   ├── Library/          Link/feed models, repositories, state, and views
│   └── Settings/         API-key onboarding and settings
├── Navigation/           Root sidebar and app lifecycle coordination
├── PreviewSupport/       Deterministic SwiftUI preview data
├── Services/             Shiori HTTP client
└── Shared/               App/extension Keychain and retry-queue code
```

SwiftUI views own presentation state. `@Observable` stores coordinate feature state, a `LinksRepository` protocol separates UI state from persistence/networking, and an actor serializes the on-disk link cache. Shared dependencies are assembled in `AppEnv` rather than accessed through global singletons.

## Privacy and security

- The Shiori API key is stored with Keychain protection and shared only between Hozon and its Action extension.
- Cached link metadata is stored as JSON in the app's Application Support directory.
- The reader loads the selected article in a nonpersistent `WKWebView` and converts it into plain semantic blocks. It does not embed the source page in the reader UI.
- Hozon contacts `www.shiori.sh`, feed/icon hosts returned by Shiori, and article URLs opened by the user.
- Logs avoid link titles, URLs, API keys, and raw server response bodies.

Please report vulnerabilities according to [SECURITY.md](SECURITY.md).

## Contributing

Bug reports and focused pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before starting a change.

Hozon is an independent project and is not an official Shiori product. “Shiori” remains the property of its respective owner.

## License

Hozon is available under the [MIT License](LICENSE).
