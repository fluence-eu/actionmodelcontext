require_relative 'lib/action_model_context/version'

Gem::Specification.new do |spec|
  spec.name = 'actionmodelcontext'
  spec.version = ActionModelContext::VERSION
  spec.authors = [ 'Jonathan PHILIPPE' ]
  spec.email = [ 'jphilippe@fluence.eu' ]

  spec.summary = 'Rails-flavoured MCP server on top of the official mcp SDK'
  spec.homepage = 'https://github.com/fluence-eu/actionmodelcontext'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/fluence-eu'
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
