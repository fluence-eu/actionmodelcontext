# Rails layer over the official `mcp` SDK: tools, resources and prompts are Ruby classes under `app/mcp`,
# served by a controller that includes {Server}.
module ActionModelContext
  # Raised by a primitive to report a failure to the client: a tool answers an error result with the message,
  # a resource or a prompt an `invalid_params` JSON-RPC error.
  #
  # @api public
  class Error < StandardError; end
end
