require_relative "lib/action_model_context/version"

Gem::Specification.new do |spec|
  spec.name = "actionmodelcontext"
  spec.version = ActionModelContext::VERSION
  spec.authors = [ "Jonathan PHILIPPE" ]
  spec.email = [ "jphilippe@fluence.eu" ]

  spec.summary = "Rails-flavoured MCP server on top of the official mcp SDK"
  spec.homepage = "https://github.com/jplot/actionmodelcontext"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jplot/actionmodelcontext"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "mcp", "~> 1.8"
  spec.add_dependency "railties", ">= 7.2"
  spec.add_dependency "actionpack", ">= 7.2"
end
