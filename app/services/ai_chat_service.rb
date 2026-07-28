# frozen_string_literal: true

require "ollama_client"

class AiChatService
  def initialize(user)
    @user = user
    @client = Ollama::Client.new
    @tool_executor = Ai::ToolExecutor.new(user)
  end

  def chat(message, history = [])
    messages = [
      { role: "system", content: build_system_prompt },
      *sanitize_history(history),
      { role: "user", content: message }
    ]

    begin
      if needs_tools?(message)
        response = @client.chat(messages: messages, tools: available_tools)
        response = handle_tool_calls(response, messages) if response.message.tool_calls&.any?
      else
        response = @client.chat(messages: messages)
      end

      { role: "assistant", content: response.message.content }
    rescue StandardError => e
      Rails.logger.error "[AiChatService] Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      raise e
    end
  end

  private

  def build_system_prompt
    Ai::PromptBuilder.new(@user).build
  end

  def available_tools
    [
      {
        type: "function",
        function: {
          name: "create_expense",
          description: "Log a new expense. Use for spending, buying, or paying expenses.",
          parameters: {
            type: "object",
            properties: {
              amount: { type: "number", description: "Amount in INR." },
              category_name: { type: "string", description: "Category name from active categories." },
              payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
              expense_date: { type: "string", description: "YYYY-MM-DD. Default is today." },
              description: { type: "string", description: "Brief description." }
            },
            required: %w[amount category_name payment_method description]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "pay_bill",
          description: "Mark an active monthly bill as paid.",
          parameters: {
            type: "object",
            properties: {
              bill_id: { type: "integer", description: "Database ID of the bill." }
            },
            required: ["bill_id"]
          }
        }
      }
    ]
  end

  def handle_tool_calls(response, messages)
    tool_calls = response.message.tool_calls
    messages << {
      role: "assistant",
      content: response.message.content || "",
      tool_calls: tool_calls.map { |tc| { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments } } }
    }

    tool_calls.each do |tc|
      result = @tool_executor.execute(tc)
      messages << { role: "tool", tool_call_id: tc.id, name: tc.name, content: result.to_json }
    end

    @client.chat(messages: messages, tools: available_tools)
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

  def needs_tools?(message)
    msg = message.to_s.downcase
    action_keywords = %w[spent log buy bought expense paid pay payed mark cost purchase]
    question_keywords = ["?", "have ", "did ", "is ", "what ", "how ", "when ", "please check"]

    is_action = action_keywords.any? { |kw| msg.include?(kw) }
    is_question = question_keywords.any? { |kw| msg.include?(kw) }

    is_action && !is_question
  end
end
