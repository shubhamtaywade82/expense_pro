# frozen_string_literal: true

# Ollama Cloud configuration for the ExpensePro AI assistant.
#
# Required environment variables:
#   OLLAMA_HOST     – Base URL for Ollama (e.g. https://api.ollama.cloud or http://localhost:11434)
#   OLLAMA_API_KEY  – API key for authentication (required for cloud; ignored for local)
#   OLLAMA_MODEL    – Model name (defaults to llama3.3-70b-instruct if unset)
#
# The AiChatService reads these from ENV at request time via Ollama::Config.new,
# so there is no global client object to configure here. This file exists to
# document the available settings and verify availability of the ollama-client gem.
#
# Usage in app/services/ai_chat_service.rb:
#   config = Ollama::Config.new(
#     base_url: ENV.fetch("OLLAMA_HOST", "http://localhost:11434"),
#     api_key:  ENV["OLLAMA_API_KEY"]
#   )
#   client = Ollama::Client.new(config)

Rails.application.config.after_initialize do
  ollama_host = ENV["OLLAMA_HOST"]
  ollama_key  = ENV["OLLAMA_API_KEY"]

  if ollama_host.present? && ollama_key.blank?
    Rails.logger.warn "[Ollama] OLLAMA_HOST is set but OLLAMA_API_KEY is missing — requests may fail"
  end

  if ollama_host.present?
    Rails.logger.info "[Ollama] Configured: #{ollama_host} | Model: #{ENV.fetch("OLLAMA_MODEL", "llama3.3-70b-instruct")}"
  end
end
