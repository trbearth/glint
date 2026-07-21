# Contributing to Glint

Open an issue before large architectural work so effort is not duplicated.

Glint development requires macOS 13+ and Xcode or Command Line Tools:

```sh
./scripts/build-app.sh
swift test
```

Before opening a pull request, run `sh -n scripts/*.sh scripts/glint-run`, run the test suite, build the app, and test any hook you changed. Never commit personal paths, transcripts, credentials, generated `Glint.app`, or user configuration. Pull requests should explain user-visible behavior, validation, privacy implications, and include screenshots for UI changes.
