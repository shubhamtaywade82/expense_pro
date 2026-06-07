# frozen_string_literal: true

require "ollama_client"

class AiChatService
  def initialize(user)
    @user = user
    @client = Ollama::Client.new
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
    dashboard = DashboardService.new(@user, month: Date.current.month, year: Date.current.year).overview
    net_savings = calculate_net_savings(dashboard)

    <<~SYSTEM
      You are ExpensePro AI, a premium personal finance assistant.
      Use the tools provided to take actions like logging expenses or paying bills.

      Current Local Time: #{Time.current.strftime("%A, %B %d, %Y, %I:%M %p")}

      User's Current Financial Data (#{Time.current.strftime("%B %Y")}):
      - Total Income: ₹#{dashboard.dig(:income, :total)} (#{dashboard.dig(:income, :received)} received, #{dashboard.dig(:income, :expected)} expected/projected)
      - Total Expenses: ₹#{dashboard.dig(:expenses, :total)}
      - Monthly Bills: ₹#{dashboard.dig(:bills, :total)} total (#{dashboard.dig(:bills, :paid)} paid, #{dashboard.dig(:bills, :unpaid)} pending)
      - Loan EMIs: ₹#{dashboard.dig(:emis, :total)}
      - Net Savings: ₹#{calculate_net_savings(dashboard)}

      Active Categories:
      #{@user.categories.map { |c| "- #{c.name} (#{c.category_type})" }.join("\n")}

      Active Monthly Bills:
      #{@user.monthly_bills.active.map { |b| "- ID: #{b.id}, Name: #{b.name}, Amount: ₹#{b.amount}, Paid: #{b.is_paid ? 'Yes' : 'No'}" }.join("\n")}

      Recent Expenses:
      #{@user.expenses.includes(:category).recent_first.limit(5).map { |e| "- #{e.expense_date}: ₹#{e.amount} for #{e.description || e.category.name}" }.join("\n")}

      Instructions:
      1. Use 'create_expense' for spending.
      2. Use 'pay_bill' with the correct ID for paying specific bills.
      3. Do NOT hallucinate tools. All finance data is provided here; answer questions directly.
      4. DO NOT call tools like 'get_net_savings', 'get_income', 'get_expenses', or 'get_bills'. This information is ALREADY in this prompt.
      5. Only call 'pay_bill' if explicitly asked to mark it as paid.
    SYSTEM
  end

  def calculate_net_savings(dashboard)
    dashboard.dig(:income, :total).to_d -
      dashboard.dig(:expenses, :total).to_d -
      dashboard.dig(:bills, :total).to_d -
      dashboard.dig(:emis, :total).to_d
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
      result = execute_tool(tc)
      messages << { role: "tool", tool_call_id: tc.id, name: tc.name, content: result.to_json }
    end

    @client.chat(messages: messages, tools: available_tools)
  end

  def execute_tool(tool_call)
    case tool_call.name
    when "create_expense"
      args = tool_call.arguments
      category = resolve_category(args["category_name"])
      expense = @user.expenses.create!(
        amount: args["amount"].to_d,
        category: category,
        payment_method: args["payment_method"],
        expense_date: Date.parse(args["expense_date"] || Date.current.to_s),
        description: args["description"]
      )
      { success: true, message: "Expense logged", expense_id: expense.id, amount: expense.amount.to_s, category: category.name }
    when "pay_bill"
      bill = @user.monthly_bills.find_by(id: tool_call.arguments["bill_id"])
      if bill&.update(is_paid: true)
        { success: true, message: "Bill marked as paid", bill_id: bill.id, name: bill.name }
      else
        { success: false, message: "Bill not found" }
      end
    else
      { success: false, message: "Unknown tool" }
    end
  rescue StandardError => e
    { success: false, message: "Error: #{e.message}" }
  end

  def resolve_category(name)
    @user.categories.where("name ILIKE ?", name.strip).first ||
      @user.categories.find_by(name: "Other") ||
      @user.categories.create!(name: name, category_type: "expense")
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
    # Keywords that suggest an action is needed
    is_action = %w[spent log buy bought expense paid pay payed mark cost purchase].any? { |w| msg.include?(w) }
    # Keywords that suggest a question is being asked
    is_question = msg.include?("?") || msg.start_with?("have", "did", "is", "what", "how", "when", "please check")
    
    # If it's an action and NOT a simple data question, enable tools
    is_action && !is_question
  end
end
