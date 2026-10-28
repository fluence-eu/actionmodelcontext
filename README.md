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

`argument(name, type, required: false, null: false, **keywords)` where `type` is one of `:string`, `:integer`, `:number`, `:boolean`, `:array`, `:object`. `null: true` also accepts `null` (`"type": ["string", "null"]`). The other keywords are those of JSON Schema 2020-12, the dialect MCP uses (`description:`, `enum:`, `items:`, `minimum:`…), their names camelized: `argument :ids, :array, items: { type: 'integer' }, max_items: 50` emits `maxItems`. A hash such as `items:` goes through as is, so write its keys in JSON (`maxLength`). A keyword outside it, a typo such as `max_itmes:` for instance, raises `ArgumentError` when the class loads. The SDK validates the arguments against the schema before `call`, so `minimum`, `maxItems` and the like are enforced; `format` is not. The tool name defaults to the underscored class name without the `Tool` suffix (`echo`); override it with `tool_name 'other'`. `title`, `description` and `annotations(**hints)` are class-level macros.

`arguments_from(properties, required: [])` declares one argument per entry of a JSON Schema `properties` hash, the names listed in `required` being required, so one set of fields can serve a create tool and an update tool:

```ruby
TASK_FIELDS = { title: { type: 'string' }, due_on: { type: %w[string null], format: 'date' } }.freeze

class CreateTaskTool < ApplicationTool
  arguments_from TASK_FIELDS, required: %i[title]
end
```

Keys may be symbols or strings, as in a schema loaded from JSON, and `type: [..., 'null']` becomes `null: true`. A property without a single type, or with its own `required` list, raises `ArgumentError`; a `required` nested in `items` or `properties` goes through as is.

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

`argument(name, required: false, title: nil, description: nil)`: MCP gives a prompt argument no type, only these fields. `call` returns a `String` (one user message) or an `Array` of `{ role:, content: }` hashes.

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

The gem imposes no authentication unless `config.action_model_context.oauth.token_verifier` is set (see [OAuth](#oauth)). Three hooks are available, all private and overridable:

| Hook | Default | Purpose |
| --- | --- | --- |
| `mcp_context` | `{}` | The `context` given to every primitive |
| `mcp_server_options` | `{ name: <app module name, underscored> }` | Keyword arguments for `MCP::Server.new` (for example `name:`, `version:`, `instructions:`) |
| `mcp_transport_options` | `{}` | Keyword arguments for `MCP::Server::Transports::StreamableHTTPTransport.new` |

`stateless`, `enable_json_response` and `serve_subscriptions_listen` are pinned and cannot be overridden through `mcp_transport_options`: the transport is built per request, so a stateful transport would leak a session reaper thread on every call.

### OAuth

The MCP server is an OAuth 2.1 resource server: clients call it with bearer tokens issued by an authorization server (Doorkeeper in the same app, or an external identity provider), and it never issues them. Everything is set under `config.action_model_context.oauth`, in `config/application.rb` or per environment:

```ruby
config.action_model_context.oauth.resource = 'https://example.com/mcp'
config.action_model_context.oauth.authorization_servers = [ 'https://auth.example.com' ]
config.action_model_context.oauth.scopes = %w[mcp:tools]
```

`resource` is the public URL of the MCP endpoint, prefix included. With it, the gem publishes the RFC 9728 Protected Resource Metadata document, through which clients discover the authorization server, using the SDK's middleware: at the RFC 9728 path when requests for it reach the app, and at `/.well-known/oauth-protected-resource` relative to the app, the path an app mounted under a prefix receives. Without `resource`, the gem publishes nothing. `scopes` are advertised in the document and in the challenges. The optional `resource_name` and `resource_documentation` go into the document too, and `extra` adds the other RFC 9728 fields (`extra = { resource_policy_uri: '...' }`); `bearer_methods_supported` stays `["header"]`, the only place the SDK reads a token from.

Every 401 points at that document. Its URL is `resource` with the path of the MCP endpoint replaced by `/.well-known/oauth-protected-resource` (`https://example.com/backend/app/.well-known/oauth-protected-resource` for `https://example.com/backend/app/mcp`), so it keeps a prefix that a proxy strips before the request reaches the app, without relying on forwarded headers.

Then either the gem checks the token, or the app decides who calls.

#### The gem checks the token

`token_verifier` is a lambda that receives the document and returns the SDK verifier. It runs once the app has loaded, and again after each code reload in development. The concern then checks the bearer token before the MCP actions: a missing or invalid token gets a 401, a token without all of `scopes` a 403 `insufficient_scope`, both with the SDK's challenge. `mcp_access_token` returns the verified `MCP::Server::OAuth::AccessToken`:

```ruby
config.action_model_context.oauth.token_verifier = ->(metadata) {
  MCP::Server::OAuth::JWTVerifier.new(resource_metadata: metadata, jwks_uri: 'https://auth.example.com/.well-known/jwks.json')
}
```

```ruby
class McpController < ApplicationController
  include ActionModelContext::Server

  private

  def mcp_context = { user: User.find_by(id: mcp_access_token.subject) }
end
```

`JWTVerifier` (which needs the `jwt` gem) checks the signature, and the issuer and audience against the document, and caches the signing keys. `IntrospectionVerifier` asks the authorization server instead, and any object that responds to `verify(token)` and returns an `MCP::Server::OAuth::AccessToken` works too (see `MCP::Server::OAuth::TokenVerifier`).

With Doorkeeper in the same app, `authorization_servers` names the app itself and the verifier looks the token up in Doorkeeper's table:

```ruby
config.action_model_context.oauth.token_verifier = ->(_metadata) { DoorkeeperTokenVerifier.new }
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

#### The app decides who calls

Without `token_verifier`, the app authenticates the request itself, or a proxy in front of it does, as in [Authentication and context](#authentication-and-context). When it rejects a request, `request_mcp_authentication` answers the SDK's 401 challenge:

```ruby
class McpController < ApplicationController
  include ActionModelContext::Server
  before_action { request_mcp_authentication unless user_signed_in? }
end
```

### Host and Origin checks (DNS rebinding)

The concern builds the transport with `dns_rebinding_protection: false`. The transport's own check accepts only `127.0.0.1`, `::1` and `localhost` as Host, which would reject every real deployment. Host checking is left to Rails' `config.hosts` (`ActionDispatch::HostAuthorization`).

- In development, Rails allows local hosts by default. In production, `config.hosts` is empty, which means **no Host check at all** unless your app configures one. Set `config.hosts` in production.
- The same flag also disables the transport's Origin check.
- To turn the protection back on, override the option:

```ruby
def mcp_transport_options = { dns_rebinding_protection: true, allowed_hosts: %w[mcp.example.com] }
```

## I18n

Titles, descriptions, and argument titles and descriptions are looked up per request, in the current locale:

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
          topic:
            title: Topic
            description: What to summarize
```

The keys are `action_model_context.{tools,resources,prompts}.<name>.{title,description,arguments.<arg>}`, where `<name>` is the primitive name (`billing_refund` for `Billing::RefundTool`). `arguments.<arg>` holds the argument's description, or a hash with its `title` and `description`; a tool argument reads only the description. A value declared in the class (`description '...'`, `argument ..., description: '...'`) wins over I18n. I18n fallbacks apply only when `config.i18n.fallbacks` is enabled, which the `config/environments/production.rb` generated by Rails does. A missing key omits the field: "Translation missing" never reaches the client.

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
