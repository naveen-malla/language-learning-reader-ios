# Contributing Guidelines

## Code Standards

This project follows iOS development best practices and enforces code quality through SwiftLint.

### Documentation

- All public APIs, structs, classes, and enums must have documentation comments
- Use `///` for documentation comments (not `//`)
- Document parameters with `- Parameter` and return values with `- Returns:`
- Include usage examples for complex APIs

Example:
```swift
/// Normalizes text for consistent dictionary lookups and comparisons.
struct TextNormalizer {
    /// Normalizes text by trimming whitespace and converting to lowercase.
    /// - Parameter text: The text to normalize.
    /// - Returns: Normalized text suitable for dictionary keys.
    func normalize(_ text: String) -> String {
        // implementation
    }
}
```

### Access Control

- Use appropriate access modifiers: `private`, `fileprivate`, `internal`, `public`
- Default to the most restrictive access level
- Mark types as `final` when inheritance is not intended

### Error Handling

- Use proper `do-catch` blocks instead of `try?` when errors need to be logged
- Never use `try!` in production code
- Log errors appropriately without crashing the app

### Force Unwrapping

- Avoid force unwrapping (`!`) - this is enforced by SwiftLint as an error
- Use optional binding (`if let`, `guard let`) or nil coalescing (`??`)
- Use optional chaining when appropriate

### Memory Safety

- Avoid `unsafeBitCast` and other unsafe operations
- Use Swift's native types and patterns
- Ensure thread safety for shared resources

### SwiftUI Best Practices

- Use `@State`, `@Binding`, `@ObservedObject`, etc. appropriately
- Keep views focused and composable
- Extract complex view logic into separate components
- Use proper accessibility labels and hints

### Testing

- Write unit tests for business logic and utilities
- Test edge cases: empty strings, nil values, boundary conditions
- Use descriptive test names: `testNormalizesBasicText()`
- Keep tests focused on a single behavior

### Code Organization

- Group related functionality together
- Use extensions to organize code by conformance
- Keep files focused and under 500 lines
- Use `// MARK: -` to organize code sections

### SwiftLint

Run SwiftLint before committing:
```bash
swiftlint lint
```

Auto-fix issues where possible:
```bash
swiftlint --fix
```

### Git Commits

- Write clear, descriptive commit messages
- Use present tense: "Add feature" not "Added feature"
- Reference issues when applicable
- Keep commits focused on a single change

### Pull Requests

- Ensure all tests pass
- Run SwiftLint and fix all errors
- Update documentation for API changes
- Add tests for new functionality
- Keep PRs focused and reasonably sized
