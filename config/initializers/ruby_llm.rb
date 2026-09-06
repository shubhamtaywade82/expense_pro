# frozen_string_literal: true

require "ruby_llm"

RubyLLM.configure do |config|
  config.use_new_acts_as = true

  # Ollama configuration
  ollama_base = ENV.fetch("OLLAMA_API_BASE", ENV.fetch("OLLAMA_HOST", "http://localhost:11434"))
  config.ollama_api_base = ollama_base.end_with?("/v1") ? ollama_base : "#{ollama_base.chomp('/')}/v1"
  config.ollama_api_key = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"].present?

  # Cloud LLM providers
  config.gemini_api_key = ENV["GEMINI_API_KEY"] if ENV["GEMINI_API_KEY"].present?
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"] if ENV["ANTHROPIC_API_KEY"].present?
  config.openai_api_key = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
  config.deepseek_api_key = ENV["DEEPSEEK_API_KEY"] if ENV["DEEPSEEK_API_KEY"].present?

  # Default model
  config.default_model = ENV.fetch("LLM_MODEL", ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b"))
  config.request_timeout = 60
end
