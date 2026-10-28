# Contributing

Thanks for contributing! Here's how to get started:

1. Open an issue to discuss the proposed change
2. Create a branch from `main`
3. Implement the change with tests
4. Make sure `bundle exec rspec` and `bundle exec rubocop` pass
5. Open a pull request targeting `main`

---

## Setup

```bash
git clone git@github.com:fluence-eu/actionmodelcontext.git
cd actionmodelcontext
bundle install
```

Requires Ruby 3.2+. The gem supports Rails 7.2+ and `mcp` ~> 1.8.

## Development

### Running tests and linting

```bash
bundle exec rspec         # specs, against Rails 8.1 by default
bundle exec rubocop       # rubocop-rails-omakase, with single-quoted strings
bundle exec rubocop -a    # auto-fix linting
```

The specs run against a dummy Rails app in `spec/dummy`. CI runs them on every Rails version the gem supports, selected by `RAILS_VERSION`. `Gemfile.lock` is not committed, so re-resolve the bundle with the same variable to run them locally against another version, and run `bundle update` without it to come back to the default:

```bash
RAILS_VERSION='~> 7.2.0' bundle update
RAILS_VERSION='~> 7.2.0' bundle exec rspec
```

---

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <description>

[body]

[footer(s)]
```

### Types

| Type | Description |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only changes |
| `style` | Formatting changes (whitespace, commas, etc.) — no logic |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `build` | Changes to build system or dependencies |
| `ci` | CI/CD configuration changes |
| `chore` | Other changes that don't modify source or tests |
| `revert` | Revert a previous commit |

### Scope

Optional — indicates the area of the gem affected:

| Scope | Area |
|---|---|
| `tool` | `ActionModelContext::Tool` and its arguments |
| `resource` | `ActionModelContext::Resource` |
| `prompt` | `ActionModelContext::Prompt` |
| `server` | The controller concern, `ActionModelContext::Server` |
| `oauth` | `config.action_model_context.oauth`, the metadata document and the 401 challenges |
| `i18n` | Translation lookups |
| `generators` | The install, tool, resource and prompt generators |
| `test-helper` | `ActionModelContext::TestHelper` |
| `railtie` | Rails integration: autoloading of `app/mcp`, configuration, initializers |

### Description

- Imperative mood ("add", not "adds" or "added")
- No capital letter at the start
- No period at the end
- Maximum 72 characters

### Body (optional)

- Use bullet points with `-` for multiple items
- Explain **why**, not **what** (the diff speaks for itself)

### Breaking Changes

Non-backward-compatible changes must be flagged with:

- A `!` after the type/scope: `feat(tool)!: rename the required option`
- And/or a `BREAKING CHANGE:` footer in the body

### Examples

```
feat(tool): add arguments_from
```

```
fix(oauth): build the challenge's metadata URL from resource

- a proxy that strips the path prefix leaves SCRIPT_NAME empty
- the public URL declared in resource still holds the prefix
```

```
refactor(tool): store an argument as one flat hash
```

```
feat(tool)!: rename the required option

BREAKING CHANGE: argument takes mandatory: instead of required:,
tools must update their declarations.
```

---

## Branching Model

- **`main`** — default branch. All feature branches are created from here, and all PRs target this branch.
- Never push directly to `main` — always create a feature branch and open a PR.

---

## Pull Request Convention

### PR Title

- Same format as commits: `<type>(<scope>): <description>`
- Under 72 characters

### PR Classification

| Level | Criteria | Description requirements |
|---|---|---|
| **Critical** | Breaking change, security fix | Full description — summary, changes, impact, rollback plan, how to test |
| **Major** | New feature, significant refactor | Summary + changes + how to test |
| **Minor** | Small bug fix, config tweak, dependency bump | Summary + changes (1-2 lines each) |
| **Trivial** | Documentation, formatting, comment update | One-line summary is enough |

### PR Description by Level

#### Critical / Major

```markdown
## Summary
<What and why in 2-3 sentences>

## Changes
- <change 1>
- <change 2>

## How to Test
1. <step 1>
2. <step 2>
```

For **Critical** PRs, also add:

```markdown
## Impact
- <what parts of the system are affected>

## Rollback Plan
- <how to safely revert if something goes wrong>
```

#### Minor

```markdown
## Summary
<One sentence>

## Changes
- <change 1>
```

#### Trivial

A one-line summary in the PR body is sufficient.

### Rules

- One topic per PR — don't mix unrelated changes
- All tests and RuboCop must pass
- New code must include tests
- Never commit secrets or credentials

---

## Architecture

```
lib/
  action_model_context.rb       # entry point
  actionmodelcontext.rb         # Bundler require shim
  action_model_context/
    primitive.rb                # shared by tools, resources and prompts: naming, I18n, rescue_from
    tool.rb                     # arguments as JSON Schema 2020-12, call
    resource.rb                 # uri and URI templates, read
    prompt.rb                   # arguments, call
    server.rb                   # controller concern: discovery, transport, OAuth
    railtie.rb                  # autoloading of app/mcp, config.action_model_context
    protected_resource_metadata_middleware.rb  # the SDK's middleware, served under the app's prefix
    translation.rb, naming.rb, error.rb, error_reporter.rb, test_helper.rb, version.rb
  generators/                   # install, tool, resource and prompt, with their RSpec and Minitest generators
```

- The protocol is delegated to the official [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk) SDK; the gem only adds the Rails layer. Reuse the SDK rather than reimplementing it.
- Primitives live under `app/mcp/{tools,resources,prompts}`, collapsed by Zeitwerk, and are discovered through the `descendants` of `ApplicationTool`, `ApplicationResource` and `ApplicationPrompt`.
- The server and the transport are built for each request, stateless.

## Tests

- Framework: RSpec (`spec/`), with a dummy Rails app in `spec/dummy`
- Request specs go through a real `MCP::Server` and transport (`spec/requests`)
- All new code must be tested; a mechanism that shares state between requests needs a spec with real threads, like `spec/requests/mcp_concurrency_spec.rb`

## Code Conventions

- Strings: single quotes, unless interpolation or escapes require double quotes
- Block parameters: named (`{ |tool| tool.name }`), never numbered (`_1`, `_2`…) nor the implicit `it`
- One-expression methods are endless: `def argument_names = arguments.keys`
- Hash and keyword shorthand: `argument(name, type, null:)`, not `null: null`
- Comments only for the non-obvious why, and generic: no deployment-specific names, hosts or paths
- RuboCop: no rule disabling without justification

## CI

GitHub Actions:

- **ci.yml** — on every PR and on `main`: RSpec on Ruby 3.2 to 4.0 × Rails 7.2, 8.0 and 8.1, and RuboCop

---

## AI-Assisted Contributions

When using AI tools (Claude, Copilot, etc.) to generate commits or PRs:

- **Classify first** — determine if the change is critical, major, minor, or trivial
- **Focus on the "why"** — the diff already shows the "what"
- **Skip boilerplate** — don't add empty sections or placeholder text

The person opening the PR takes full responsibility for the code. Before submitting:

- [ ] I have read and understood every line of code in this PR
- [ ] I can explain why each change was made
- [ ] I have tested the changes locally

Do **not** add AI co-author lines (`Co-Authored-By`), "Generated with" footers, or any AI attribution in commits or PR descriptions.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE.txt).
