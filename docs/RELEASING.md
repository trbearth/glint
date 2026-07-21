# Releasing Glint

1. Update `CFBundleShortVersionString`, `CFBundleVersion`, and `CHANGELOG.md`.
2. Run CI and test installation, update, hooks, launch at login, and uninstall on a clean macOS account.
3. Build a universal release with the intended deployment target.
4. Sign the app with a Developer ID Application certificate, submit it to Apple's notary service, and staple the ticket.
5. Package `Glint.app`, `scripts/`, `README.md`, `LICENSE`, and `CHANGELOG.md`; generate a SHA-256 checksum.
6. Create a draft GitHub Release, verify it on a second Mac, then publish it.

The included release workflow produces an **ad-hoc-signed draft artifact for testing**. Do not present that artifact as a notarized public release. Replace its signing step with project-secret-backed Developer ID signing and notarization before launch.
