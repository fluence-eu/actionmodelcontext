# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

First release.

### Added

- Tools, resources, resource templates and prompts as plain Ruby classes under `app/mcp/`, served by the `ActionModelContext::Server` controller concern over the SDK's Streamable HTTP transport, stateless with JSON responses
- `argument` on tools takes `required:`, `null:` and any JSON Schema 2020-12 keyword, in snake_case or camelCase; `arguments_from` declares the arguments from a JSON Schema `properties` hash
- Titles and descriptions of primitives and their arguments read from I18n in the current locale, with Rails fallbacks
- `rescue_from` on primitives; unhandled failures are reported through `Rails.error`
- OAuth through `config.action_model_context.oauth`: the RFC 9728 Protected Resource Metadata document, served under the app's path prefix, bearer token checks with `token_verifier`, and 401 and 403 challenges that point to the document
- Generators for the install, tools, resources and prompts, with their RSpec or Minitest tests
- `ActionModelContext::TestHelper#call_tool`
