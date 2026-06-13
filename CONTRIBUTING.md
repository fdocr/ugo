# Contributing to ugo

Thank you for your interest in contributing. ugo is an open source Rails app — bug reports, documentation improvements, and pull requests are welcome.

## Getting started

For local development setup, system requirements, and an overview of the codebase, see the [Local Quickstart](docs/local-quickstart.md).

## Reporting bugs

Search [existing issues](https://github.com/fdocr/ugo/issues) before opening a new one. When filing a bug report, include:

- A clear title and description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Your Ruby and Rails versions (`ruby -v`, `bin/rails -v`)

Screenshots or logs help when the issue is visual or involves background jobs.

## Security issues

**Do not open a public GitHub issue for security vulnerabilities.** Report them privately via [GitHub Security Advisories](https://github.com/fdocr/ugo/security/advisories/new) so a fix can be coordinated before disclosure.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your changes with tests where the behavior warrants them.
3. Run the test suite and linters before opening the PR:

   ```bash
   bin/rails db:test:prepare test test:system
   bin/rubocop
   bin/brakeman --no-pager
   bin/importmap audit
   ```

4. Open a pull request against `main` with a concise description of the change and why it is needed. Link any related issues.

Small, focused PRs are easier to review and merge. If you are planning a larger change (new feature, architectural shift), open an issue first to discuss the approach.

## Code style

This project follows [RuboCop Rails Omakase](https://github.com/rails/rubocop-rails-omakase). Run `bin/rubocop` and fix any offenses before submitting.

JavaScript is managed with [importmap-rails](https://github.com/rails/importmap-rails) — no Node.js build step. Pin new packages with `bin/importmap` and commit the vendored files under `vendor/javascript/`.

## License

By contributing, you agree that your contributions will be licensed under the same [O'Saasy License](LICENSE.md) that covers the project.
