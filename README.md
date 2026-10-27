# actionmodelcontext

A Rails-flavoured MCP server layer on top of the official [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk) SDK. Tools, resources and prompts are plain Ruby classes under `app/mcp/`, discovered by Zeitwerk, and served by a controller concern over the Streamable HTTP transport (stateless, JSON responses).

Requires Ruby 3.2+, Rails 7.2+ and `mcp` ~> 1.8.

## Installation

```sh
bundle add actionmodelcontext
bin/rails generate action_model_context:install
```

The install generator creates `ApplicationTool`, `ApplicationResource` and `ApplicationPrompt` under `app/mcp/`, an `McpController`, and this route:

```ruby
resource :mcp, controller: :mcp, only: %i[show create destroy]
```

Files under `app/mcp/tools`, `app/mcp/resources` and `app/mcp/prompts` are autoloaded with that first directory level collapsed: `app/mcp/tools/billing/refund_tool.rb` defines `Billing::RefundTool`. The controller discovers primitives through `ApplicationTool`, `ApplicationResource` and `ApplicationPrompt` and their `descendants`.

Only concrete classes are exposed. A tool or prompt is concrete when it, or a parent below the gem's base class, defines `call`. A resource is concrete when it declares its own `uri` and defines `read` (`uri` is not inherited). An intermediate base such as `Admin::BaseTool < ApplicationTool` that only adds `rescue_from` handlers or arguments is therefore not listed, while its subclasses that define `call` are. A base that defines `call` itself is exposed as a tool.

> `ApplicationResource` collides with Graphiti and JSONAPI::Resources, which also define a top-level `ApplicationResource` (in `app/resources/`). The controller looks up MCP resources through that constant on every request, so when it names the other library's class, every MCP request fails with a 500, `tools/list` and `tools/call` included, not just resources. An app using one of these libraries has to resolve the clash before installing this gem.

## Tools

```ruby
class EchoTool < ApplicationTool
  argument :message, :string, required: true
  argument :times, :integer

  def call(message:, times: 1) = message * times
end
```

`argument(name, type, required: false, description: nil, enum: nil, items: nil, properties: nil, null: false, **keywords)` where `type` is one of `:string`, `:integer`, `:number`, `:boolean`, `:array`, `:object`. `null: true` also accepts `null` (`"type": ["string", "null"]`). Any other JSON Schema 2020-12 keyword, the dialect MCP uses, goes through, its name camelized: `argument :ids, :array, items: { type: 'integer' }, max_items: 50` emits `maxItems`. A keyword outside it, a typo such as `max_itmes:` for instance, raises `ArgumentError` when the class loads. The SDK validates the arguments against the schema before `call`, so `minimum`, `maxItems` and the like are enforced; `format` is not. The tool name defaults to the underscored class name without the `Tool` suffix (`echo`); override it with `tool_name 'other'`. `title`, `description` and `annotations(**hints)` are class-level macros.

`call` may return a `String`, a `Hash` (sent as text and as structured content), an `Array`, or an `MCP::Tool::Response`. Raise `ActionModelContext::Error` to return an error result to the model with your message; any other exception is reported through `Rails.error` (`severity: :error`, `source: 'actionmodelcontext'`), with the JSON-RPC method and the primitive's name or URI as `mcp_method` and `mcp_name` in the context, never the arguments. `rescue_from` works inside a primitive:

```ruby
class WhoAmITool < ApplicationTool
  rescue_from(KeyError) { raise ActionModelContext::Error, 'Unknown user' }

  def call = { user: context.fetch(:user) }
end
```

A handler that returns normally has handled the exception, as in a Rails controller: its return value becomes the result, converted like the value of `call` (or of `read` in a resource). To produce an error result instead, raise `ActionModelContext::Error` from the handler, as above. When no handler matches the exception, its `cause` is tried next, as in Rails.

To wrap every call of a tool base, override the private `invoke(arguments)` and call `super`, as `process_action` in a controller. It receives the arguments as the client sent them, before they are sliced to the declared ones, and returns the value of `call` before its conversion. `rescue_from` covers it:

```ruby
class ApplicationTool < ActionModelContext::Tool
  private

  def invoke(arguments)
    raise ActionModelContext::Error, 'Archived records are read-only' if arguments.key?(:archived)

    Current.set(user: context[:user]) { super }
  end
end
```

## Resources

```ruby
class ReadmeResource < ApplicationResource
  uri 'app://readme'

  def read = 'Hello'
end

class UserResource < ApplicationResource
  uri 'users://{id}'

  def read(id:)
    raise ActionModelContext::Error, 'Unknown user' if id == '0'

    { id:, viewer: context[:user] }
  end
end
```

A URI containing `{variable}` is registered as a resource template, and the variables are passed to `read` as keyword arguments. `read` may return a `String` (`text/plain`), or a `Hash` / `Array` (`application/json`); `mime_type '...'` overrides this and is inherited by subclasses, unlike `uri`. An `ActionModelContext::Error` becomes an `invalid_params` JSON-RPC error.

## Prompts

```ruby
class SummarizePrompt < ApplicationPrompt
  argument :topic, required: true

  def call(topic:) = "Summarize #{topic} in three points"
end
```

`call` returns a `String` (one user message) or an `Array` of `{ role:, content: }` hashes.

## Generators

```sh
bin/rails generate action_model_context:tool Billing::Refund amount:integer:required reason
bin/rails generate action_model_context:resource User --uri "users://{id}"
bin/rails generate action_model_context:prompt Summarize topic:required
```

Each generator drops its own suffix (`Tool`, `Resource`, `Prompt`) from the name, so `action_model_context:tool FindUserTool` generates `FindUserTool`, not `FindUserToolTool`. Each one also generates a spec (RSpec) or test (Minitest) following your `test_framework`. Until you implement it, the generated `call` or `read` raises `ActionModelContext::Error`, so a fresh stub answers an error result (`isError` for a tool, a JSON-RPC `-32602` error for a resource or prompt) instead of a 500.

## Authentication and context

The controller is a normal Rails controller, so authenticate with a `before_action`, and expose what tools need through `mcp_context`. Whatever it returns is available as `context` in every tool, resource and prompt:

```ruby
class McpController < ApplicationController
  include ActionModelContext::Server
  before_action :authenticate_user!

  private

  def mcp_context = { user: current_user }
end
```

The gem imposes no authentication. Three hooks are available, all private and overridable:

| Hook | Default | Purpose |
| --- | --- | --- |
| `mcp_context` | `{}` | The `context` given to every primitive |
| `mcp_server_options` | `{ name: <app module name, underscored> }` | Keyword arguments for `MCP::Server.new` (for example `name:`, `version:`, `instructions:`) |
| `mcp_transport_options` | `{}` | Keyword arguments for `MCP::Server::Transports::StreamableHTTPTransport.new` |

`stateless`, `enable_json_response` and `serve_subscriptions_listen` are pinned and cannot be overridden through `mcp_transport_options`: the transport is built per request, so a stateful transport would leak a session reaper thread on every call.

### OAuth

The MCP server is an OAuth 2.1 resource server: it checks bearer tokens issued by an authorization server (Doorkeeper in the same app, or an external identity provider) and never issues them. The SDK implements this role.

Clients discover the authorization server through an RFC 9728 Protected Resource Metadata document. It is served at the origin root (`/.well-known/oauth-protected-resource/mcp` for a server at `/mcp`) and without authentication, which is what the SDK's middleware does. `resource` must be the exact URL clients connect to.

#### External authorization server

With an identity provider that issues JWTs, the SDK's `JWTVerifier` (which needs the `jwt` gem) checks the signature, and the issuer and audience against the document. Build it once, at boot: it caches the signing keys per instance. `IntrospectionVerifier` asks the authorization server instead, and any object that responds to `verify(token)` and returns an `MCP::Server::OAuth::AccessToken` works too (see `MCP::Server::OAuth::TokenVerifier`).

```ruby
# config/initializers/mcp_oauth.rb
metadata = MCP::Server::OAuth::ProtectedResourceMetadata.new(
  resource: 'https://app.example.com/mcp',
  authorization_servers: [ 'https://auth.example.com' ],
  scopes_supported: %w[mcp:tools],
)
Rails.application.config.x.mcp_resource_metadata = metadata
Rails.application.config.x.mcp_token_verifier = MCP::Server::OAuth::JWTVerifier.new(
  resource_metadata: metadata, jwks_uri: 'https://auth.example.com/.well-known/jwks.json',
)
Rails.application.config.middleware.use MCP::Server::OAuth::ProtectedResourceMetadataMiddleware, metadata
```

#### Authorization server in the same app (Doorkeeper)

The document names the app itself, and the verifier looks the token up in Doorkeeper's table instead of checking a signature:

```ruby
# config/initializers/mcp_oauth.rb
metadata = MCP::Server::OAuth::ProtectedResourceMetadata.new(
  resource: 'https://app.example.com/mcp',
  authorization_servers: [ 'https://app.example.com' ],
  scopes_supported: %w[mcp:tools],
)
Rails.application.config.x.mcp_resource_metadata = metadata
Rails.application.config.middleware.use MCP::Server::OAuth::ProtectedResourceMetadataMiddleware, metadata
```

```ruby
# app/mcp/doorkeeper_token_verifier.rb
class DoorkeeperTokenVerifier
  def verify(token)
    access_token = Doorkeeper::AccessToken.by_token(token)
    raise MCP::Server::OAuth::InvalidTokenError unless access_token&.accessible?

    MCP::Server::OAuth::AccessToken.new(
      token:, scopes: access_token.scopes.to_a, subject: access_token.resource_owner_id.to_s,
      expires_at: access_token.expires_at&.to_i, client_id: access_token.application&.uid,
    )
  end
end
```

Doorkeeper serves `/oauth/authorize` and `/oauth/token` with PKCE. MCP clients need two more things that Doorkeeper 5.9 does not provide:

- the authorization server metadata (RFC 8414) at `/.well-known/oauth-authorization-server`, whose `issuer` must equal the URL in `authorization_servers` and whose `code_challenge_methods_supported` must include `S256`;
- a way to obtain a `client_id`: a Doorkeeper application registered beforehand, support for Client ID Metadata Documents, or Dynamic Client Registration (RFC 7591).

Doorkeeper tokens are not bound to the MCP endpoint: any token of the app that carries the required scope is accepted.

#### Protecting the controller

Put the SDK's bearer middleware in front of the controller, with the verifier, the same document and the required scopes. `use` scopes it to this controller. A request without a valid token gets a 401 whose `WWW-Authenticate` header points to the document, and a token missing a required scope gets a 403 `insufficient_scope`. `mcp_context` only runs for accepted requests, and finds the verified `MCP::Server::OAuth::AccessToken` in the env:

```ruby
class McpController < ApplicationController
  include ActionModelContext::Server
  use MCP::Server::OAuth::Middleware,
    token_verifier: Rails.configuration.x.mcp_token_verifier,
    resource_metadata: Rails.configuration.x.mcp_resource_metadata,
    required_scopes: %w[mcp:tools]

  private

  def mcp_context = { user: User.find_by(id: request.env[MCP::Server::OAuth::ENV_KEY].subject) }
end
```

With Doorkeeper, pass `token_verifier: DoorkeeperTokenVerifier.new`.

The transport reads the same token from the env and does not verify it again. Passing `token_verifier:` through `mcp_transport_options` instead also protects the endpoint, but the transport then verifies the token after `mcp_context` has run, so the context cannot use it.

### Host and Origin checks (DNS rebinding)

The concern builds the transport with `dns_rebinding_protection: false`. The transport's own check accepts only `127.0.0.1`, `::1` and `localhost` as Host, which would reject every real deployment. Host checking is left to Rails' `config.hosts` (`ActionDispatch::HostAuthorization`).

- In development, Rails allows local hosts by default. In production, `config.hosts` is empty, which means **no Host check at all** unless your app configures one. Set `config.hosts` in production.
- The same flag also disables the transport's Origin check.
- To turn the protection back on, override the option:

```ruby
def mcp_transport_options = { dns_rebinding_protection: true, allowed_hosts: %w[mcp.example.com] }
```

## I18n

Titles, descriptions and argument descriptions are looked up per request, in the current locale:

```yaml
en:
  action_model_context:
    tools:
      billing_refund:
        title: Refund
        description: Refund an invoice
        arguments:
          amount: Amount in cents
    resources:
      user:
        description: A user
    prompts:
      summarize:
        description: Summarize a topic
        arguments:
          topic: What to summarize
```

The keys are `action_model_context.{tools,resources,prompts}.<name>.{title,description,arguments.<arg>}`, where `<name>` is the primitive name (`billing_refund` for `Billing::RefundTool`). A value declared in the class (`description '...'`, `argument ..., description: '...'`) wins over I18n. I18n fallbacks apply only when `config.i18n.fallbacks` is enabled, which the `config/environments/production.rb` generated by Rails does. A missing key omits the field: "Translation missing" never reaches the client.

Switch the locale per request in your controller:

```ruby
class McpController < ApplicationController
  include ActionModelContext::Server

  around_action :switch_locale

  private

  def switch_locale(&) = I18n.with_locale(request.headers['Accept-Language'].presence_in(%w[en fr]) || :en, &)
end
```

This sample only matches a header that is exactly `en` or `fr`. A real `Accept-Language` header such as `fr-FR,fr;q=0.9,en;q=0.8` has to be parsed first.

> Do not mix languages across tools in one server. Descriptions in several languages degrade tool selection by the model (see [modelcontextprotocol issue #1395](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1395)). Serve one consistent locale per client.

## Testing

`ActionModelContext::TestHelper` runs a tool through a real `MCP::Server`, so argument validation and error handling behave as in production:

```ruby
require 'action_model_context/test_helper'

RSpec.describe EchoTool do
  include ActionModelContext::TestHelper

  it 'repeats the message' do
    result = call_tool(EchoTool, message: 'hi', times: 2)

    expect(result.text).to eq('hihi')
    expect(result).not_to be_error
  end

  it 'passes the context' do
    expect(call_tool(WhoAmITool, context: { user: 'ada' }).structured_content).to eq(user: 'ada')
  end
end
```

`call_tool(tool_class, context: {}, **arguments)` returns a result with `text`, `structured_content` and `error?`. An unexpected exception raised by the tool is re-raised in the test.

## License

MIT.
