class EchoTool < ApplicationTool
  argument :message, :string, required: true
  argument :times, :integer

  def call(message:, times: 1) = message * times
end
