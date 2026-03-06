# Contributing to GlobeDisplay

Thank you for your interest in contributing. GlobeDisplay is an open-source project for the MagicPlanet community — educators, museum professionals, and science enthusiasts.

## Ways to Contribute

- **Bug reports** — open a GitHub issue with steps to reproduce
- **Content packs** — curated SOS-format dataset bundles for the community
- **Feature requests** — open an issue describing the use case
- **Code contributions** — see workflow below

## Code Contribution Workflow

1. **Open an issue first** for any significant change so we can discuss the approach before you invest time coding.
2. Fork the repository and create a feature branch: `git checkout -b feat/your-feature-name`
3. Make your changes following the conventions below.
4. Run the test suite: Cmd+U in Xcode (or `xcodebuild test`).
5. Open a pull request against `main` with a clear description.

## Coding Conventions

- **Swift 6** with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- **No force-unwraps** in production code — use `guard` or `if let`
- **Actor isolation** — `RenderEngine` is an actor; never call its methods from non-async contexts
- **Naming** — Swift API Design Guidelines (PascalCase types, camelCase properties/methods)
- **Commits** — conventional commit format: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`

## Content Contributions

Community-contributed content packs are welcome. See [CONTENT_GUIDE.md](Documentation/CONTENT_GUIDE.md) for the SOS bundle format. Content must:

- Use public domain or appropriately licensed imagery
- Include accurate attribution in `label.json`
- Be in equirectangular projection, 2:1 aspect ratio
- Have an educational description in English

## Testing

Before submitting a pull request, verify:

- [ ] Project builds without errors or warnings (`xcodebuild build`)
- [ ] All existing tests pass (`xcodebuild test`)
- [ ] New code has tests where applicable (target: 80%+ coverage for Models/DataFeeds/Utilities)
- [ ] No SourceKit errors remain after a clean build

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.
