# frozen_string_literal: true

require "ollama_client"

class AiChatService
  def initialize(user)
    @user = user
    @client = Ollama::Client.new
  end

  def chat(message, history = [])
    # 1. Fetch current user context
    dashboard = DashboardService.new(@user, month: Date.current.month, year: Date.current.year).overview
    
    categories = @user.categories.map { |c| "- #{c.name} (#{c.category_type})" }.join("\n")
    
    bills = @user.monthly_bills.active.map do |b|
      "- ID: #{b.id}, Name: #{b.name}, Category: #{b.category.name}, Amount: ₹#{b.amount}, Due Day: #{b.due_date}, Paid: #{b.is_paid ? 'Yes' : 'No'}"
    end.join("\n")
    
    recent_expenses = @user.expenses.includes(:category).recent_first.limit(10).map do |e|
      "- #{e.expense_date.strftime('%Y-%m-%d')}: ₹#{e.amount} for '#{e.description || e.category.name}' (Category: #{e.category.name}, Paid via: #{e.payment_method})"
    end.join("\n")
    
    # Calculate net savings
    total_income = dashboard.dig(:income, :total).to_d
    total_expense = dashboard.dig(:expenses, :total).to_d
    total_bills = dashboard.dig(:bills, :total).to_d
    total_emi = dashboard.dig(:emis, :total).to_d
    net_savings = total_income - total_expense - total_bills - total_emi

    # 2. Build system prompt
    system_prompt = <<~SYSTEM
      You are ExpensePro AI, a premium personal finance assistant.
      You help users manage their expenses, track budgets, analyze savings, and manage bills.
      
      Use the tools provided to take actions on behalf of the user, such as logging a new expense or paying an active monthly bill.
      If the user asks about their finances, refer to their current financial data provided below.
      
      Current Local Time: #{Time.current.strftime("%A, %B %d, %Y, %I:%M %p")}
      
      User's Current Financial Data for this month (#{Time.current.strftime("%B %Y")}):
      - Total Income: ₹#{total_income}
      - Total Expenses logged: ₹#{total_expense}
      - Monthly Bills: ₹#{total_bills} total (#{dashboard.dig(:bills, :paid)} paid, #{dashboard.dig(:bills, :unpaid)} pending)
      - Loan EMIs: ₹#{total_emi}
      - Calculated Net Savings: ₹#{net_savings}
      
      Active Categories in the system:
      #{categories.presence || 'None'}
      
      Active Monthly Bills to Pay:
      #{bills.presence || 'None'}
      
      Recent 10 Expenses Logged:
      #{recent_expenses.presence || 'None'}
      
      Important Instructions:
      1. If a user tells you they spent money, bought something, or paid an expense, call the 'create_expense' tool.
      2. If a user tells you they paid a specific bill (like Rent, Electricity, etc.), check the list of active bills to find its ID, and call the 'pay_bill' tool with the correct ID.
      3. When an action is successfully executed via a tool, confirm the details.
      4. Always respond politely, in a helpful manner, and formatting numbers nicely (in ₹ or INR). Keep responses concise.
      5. DO NOT invent, hallucinate, or make up any other tools (such as 'get_net_savings' or 'get_expenses'). For questions about savings, bills, or expenses, you ALREADY have all the data in this system prompt context. Answer these questions directly in natural language without calling any tools!
      6. Do NOT call 'pay_bill' if they are just asking whether they paid it or asking about the bill status. Only call 'pay_bill' when they say they paid it or explicitly ask to pay/mark it paid.
    SYSTEM

    # 3. Format messages list
    formatted_messages = [{ role: "system", content: system_prompt }]
    
    # Sanitize and add history
    sanitize_history(history).each do |msg|
      formatted_messages << msg
    end
    
    # Add new message
    formatted_messages << { role: "user", content: message }

    # 4. Call Ollama chat
    begin
      if needs_tools?(message)
        # Define tools
        tools = [
          {
            type: "function",
            function: {
              name: "create_expense",
              description: "Log a new expense record in the database. Use this when the user mentions spending money, buying something, or paying for an expense.",
              parameters: {
                type: "object",
                properties: {
                  amount: { type: "number", description: "The amount spent in INR (rupees)." },
                  category_name: { type: "string", description: "The category name. Must match one of the active categories (e.g. Groceries, Travel, Dining Out, Entertainment, Health, Shopping, Rent, Other)." },
                  payment_method: { type: "string", enum: ["cash", "credit_card", "debit_card", "upi", "net_banking", "other"], description: "The payment method used." },
                  expense_date: { type: "string", description: "The date when the expense occurred in YYYY-MM-DD format. Default is today's date if not specified." },
                  description: { type: "string", description: "A brief description of what was purchased." }
                },
                required: ["amount", "category_name", "payment_method", "description"]
              }
            }
          },
          {
            type: "function",
            function: {
              name: "pay_bill",
              description: "Mark an active monthly bill as paid in the database.",
              parameters: {
                type: "object",
                properties: {
                  bill_id: { type: "integer", description: "The database ID of the bill to pay. Retrieve this from the system prompt's list of active bills." }
                },
                required: ["bill_id"]
              }
            }
          }
        ]

        response = @client.chat(messages: formatted_messages, tools: tools)
        
        # Check for tool calls
        if response.message.tool_calls&.any?
          # Capture tool calls execution for assistant message
          tool_calls_data = response.message.tool_calls.map do |tc|
            {
              id: tc.id,
              type: "function",
              function: { name: tc.name, arguments: tc.arguments.to_json }
            }
          end

          # Add assistant message with tool calls to history
          formatted_messages << {
            role: "assistant",
            content: response.message.content || "",
            tool_calls: tool_calls_data
          }

          # Execute each tool and append tool response
          response.message.tool_calls.each do |tool_call|
            Rails.logger.info "[AiChatService] Executing tool: #{tool_call.name} with args: #{tool_call.arguments}"
            result = execute_tool(tool_call)
            formatted_messages << {
              role: "tool",
              tool_call_id: tool_call.id,
              name: tool_call.name,
              content: result.to_json
            }
          end

          # Call the model again with the tool response context
          response = @client.chat(messages: formatted_messages, tools: tools)
        end
      else
        # If no tools are needed, call chat without tools to prevent hallucinations
        response = @client.chat(messages: formatted_messages)
      end

      {
        role: "assistant",
        content: response.message.content
      }
    rescue => e
      Rails.logger.error "[AiChatService] Error in chat: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      raise e
    end
  end

  private

  def execute_tool(tool_call)
    case tool_call.name
    when "create_expense"
      args = tool_call.arguments
      amount = args["amount"].to_d
      category_name = args["category_name"]
      payment_method = args["payment_method"]
      expense_date = args["expense_date"].presence || Date.current.to_s
      description = args["description"]
      
      # Resolve category case-insensitively
      category = @user.categories.where("name ILIKE ?", category_name.strip).first
      category ||= @user.categories.where(name: "Other").first
      category ||= @user.categories.create!(name: category_name, category_type: "expense", icon: "wallet", color: "#6366f1")
      
      expense = @user.expenses.create!(
        amount: amount,
        category: category,
        payment_method: payment_method,
        expense_date: Date.parse(expense_date),
        description: description
      )
      
      { success: true, message: "Expense logged successfully", expense_id: expense.id, amount: expense.amount.to_s, category: category.name }
    when "pay_bill"
      args = tool_call.arguments
      bill_id = args["bill_id"].to_i
      
      bill = @user.monthly_bills.find_by(id: bill_id)
      if bill
        bill.update!(is_paid: true)
        { success: true, message: "Bill marked as paid", bill_id: bill.id, name: bill.name, amount: bill.amount.to_s }
      else
        { success: false, message: "Bill not found with ID #{bill_id}" }
      end
    else
      { success: false, message: "Unknown tool #{tool_call.name}" }
    end
  rescue => e
    { success: false, message: "Error executing tool: #{e.message}" }
  end

  def sanitize_history(history)
    history.map do |msg|
      role = msg[:role] || msg["role"]
      content = msg[:content] || msg["content"]
      
      # If the content looks like a hallucinated JSON tool call, clean it up
      if content.to_s.strip.start_with?("{") && content.to_s.include?("name")
        begin
          parsed = JSON.parse(content)
          content = "Requested action: #{parsed['name']} with parameters #{parsed['parameters'] || parsed['arguments']}"
        rescue JSON::ParserError
          content = content.to_s.gsub(/[{}]/, "")
        end
      end

      { role: role, content: content }
    end
  end

  def needs_tools?(message)
    msg = message.to_s.downcase
    # It must contain logging or paying keywords
    return false unless %w[spent log buy bought expense paid pay payed mark cost purchase].any? { |word| msg.include?(word) }
    # But if it is a question, we don't want to pass tools to prevent hallucinations
    return false if msg.include?("?") || msg.start_with?("have", "did", "is", "what", "how", "when", "can you tell", "please check")
    
    true
  end
end
