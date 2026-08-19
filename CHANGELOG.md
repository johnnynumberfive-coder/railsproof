# Changelog

All notable changes to RailsProof will be documented in this file.

## 1.0.0 - 2026-08-19

First public release of RailsProof.

### Added

- Rails model discovery and inspection.
- Rails controller discovery and inspection.
- Deterministic Minitest generation for supported model behavior.
- Deterministic controller test generation for routed actions.
- Existing Minitest test discovery and coverage analysis.
- Support for Rails-style `test "..." do` tests.
- Support for method-style `def test_...` tests.
- Automatic AI-assisted test analysis during the normal RailsProof workflow.
- Provider-agnostic AI client architecture.
- OpenAI provider adapter.
- Structured AI test suggestions containing:
  - suggestion kind
  - test name
  - reason
  - candidate Minitest code
- `coverage` AI suggestions for additional application-specific coverage.
- `contract_check` suggestions for possible implementation/contract disagreements.
- Structural validation of AI-generated tests before execution.
- One-at-a-time candidate test execution.
- Automatic rollback of failing generated tests.
- `KEPT` status for valid generated tests that pass.
- `NEEDS REVIEW` status for valid generated tests that fail against the application.
- `REJECTED` status for malformed or unusable generated tests.
- `SKIPPED` status for deterministic duplicate suppression.
- Persistent review findings under `.rails_proof/review`.
- Source fingerprints for review findings.
- Source-aware review convergence.
- Deterministic deduplication of repeated AI findings.
- Recognition of semantically equivalent findings when AI wording changes.
- Setup-sensitive behavior identity to avoid suppressing distinct tests that share assertion text.
- Duplicate suppression for repeated suggestions within the same AI response.
- Detection of AI suggestions already represented by the live test suite.
- Test runner support for normal Rails applications and the RailsProof dummy application.
- RailsProof integration test suite and dummy Rails application.

### Notes

RailsProof 1.0.0 targets Rails 8.1 and Ruby 4.0 or newer.

Minitest is the currently supported test framework.

OpenAI is the first AI provider adapter. The OpenAI Ruby SDK is optional and is only required when using that provider.

RailsProof is still under active development. Review-management commands, additional Rails component types, richer deterministic analysis, and additional AI providers are planned for future releases.