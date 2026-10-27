class SummarizePrompt < ApplicationPrompt
  argument :topic, required: true

  def call(topic:) = "Summarize #{topic} in three points"
end
