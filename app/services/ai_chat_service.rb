# frozen_string_literal: true

class AiChatService
  attr_reader :user, :provider, :model, :tool_executor

  def initialize(user)
    @user = user
    @tool_executor = Ai::ToolExecutor.new(user)
    @provider, @model = resolve_provider_and_model
  end

  def chat(message, history = [])
    system_prompt = build_system_prompt
    tools = Ai::ToolRegistry.ruby_llm_tools_for(message, @tool_executor, @provider)

    chat_session = RubyLLM.chat(model: @model, provider: @provider)
                          .with_instructions(system_prompt)
                          .with_tools(*tools)

    sanitize_history(history).each do |msg|
      role = (msg[:role] || msg["role"]).to_s.to_sym
      chat_session.add_message(role: role, content: (msg[:content] || msg["content"]).to_s)
    end

    response = chat_session.ask(message)
    content = handle_response_content(response, chat_session)

    { role: "assistant", content: content }
  rescue StandardError => e
    Rails.logger.error "[AiChatService] Error: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}"
    { role: "assistant", content: "Sorry, I encountered an error: #{e.message}" }
  end

  def available_tools
    Ai::ToolRegistry.definitions
  end

  def self.all_tools
    Ai::ToolRegistry.definitions
  end

  private

  def handle_response_content(response, chat_session)
    content = response.content.to_s
    pseudo_call = extract_pseudo_tool(content)
    return content unless pseudo_call

    tool_name, args = pseudo_call
    result = @tool_executor.execute(tool_name, args)
    follow_up = chat_session.ask("Tool #{tool_name} returned: #{result.to_json}. Summarize this accurately for the user in ₹ (INR).")
    follow_up.content.to_s
  end

  def extract_pseudo_tool(content)
    match = content.match(/```(?:python|ruby)?\s*([a-zA-Z0-9_]+)\((.*?)\)\s*```/m)
    return nil unless match

    name = match[1]
    return nil unless Ai::ToolRegistry.definitions.any? { |d| d[:name] == name }

    args = {}
    match[2].scan(/([a-zA-Z0-9_]+)\s*=\s*(['"]?)(.*?)\2(?=[,\s]|$)/) { |k, _, v| args[k] = v }
    [name, args]
  end

  def resolve_provider_and_model
    if ENV["LLM_PROVIDER"].present?
      provider = ENV["LLM_PROVIDER"].downcase.to_sym
      model = ENV["LLM_MODEL"] || default_model_for(provider)
      [provider, model]
    elsif ENV["GEMINI_API_KEY"].present?
      [:gemini, ENV.fetch("LLM_MODEL", "gemini-2.5-flash")]
    elsif ENV["ANTHROPIC_API_KEY"].present?
      [:anthropic, ENV.fetch("LLM_MODEL", "claude-3-7-sonnet-20250219")]
    elsif ENV["OPENAI_API_KEY"].present?
      [:openai, ENV.fetch("LLM_MODEL", "gpt-5.4")]
    else
      [:ollama, ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b")]
    end
  end

  def default_model_for(provider)
    case provider
    when :gemini then "gemini-2.5-flash"
    when :anthropic then "claude-3-7-sonnet-20250219"
    when :openai then "gpt-5.4"
    when :deepseek then "deepseek-chat"
    else ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b")
    end
  end

  def build_system_prompt
    Ai::PromptBuilder.new(@user).build
  end

  def sanitize_history(history)
    history.map do |msg|
      content = msg[:content] || msg["content"]
      if content.to_s.start_with?("{") && content.to_s.include?("name")
        begin
          parsed = JSON.parse(content)
          content = "Requested: #{parsed['name']} with #{parsed['parameters'] || parsed['arguments']}"
        rescue JSON::ParserError
          content = content.to_s.gsub(/[{}]/, "")
        end
      end
      { role: msg[:role] || msg["role"], content: content }
    end
  end
end
