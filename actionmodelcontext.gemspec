require_relative 'lib/action_model_context/version'

Gem::Specification.new do |spec|
  spec.name = 'actionmodelcontext'
  spec.version = ActionModelContext::VERSION
  spec.authors = [ 'Jonathan PHILIPPE' ]
  spec.email = [ 'jphilippe@fluence.eu' ]

  spec.summary = 'Rails-flavoured MCP server on top of the official mcp SDK'
  spec.description = 'Tools, resources and prompts as plain Ruby classes under app/mcp, discovered by Zeitwerk and served by a controller concern over the Streamable HTTP transport, with I18n, rescue_from, OAuth, generators and a test helper.'
  spec.homepage = 'https://github.com/fluence-eu/actionmodelcontext'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/fluence-eu/actionmodelcontext'
  spec.metadata['changelog_uri'] = 'https://github.com/fluence-eu/actionmodelcontext/blob/main/CHANGELOG.md'
  spec.metadata['github_repo'] = 'https://github.com/fluence-eu/actionmodelcontext'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*', 'LICENSE.txt', 'README.md']
  spec.require_paths = [ 'lib' ]

  spec.add_dependency 'mcp', '~> 1.8'
  spec.add_dependency 'railties', '>= 7.2'
  spec.add_dependency 'actionpack', '>= 7.2'
end
