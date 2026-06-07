# frozen_string_literal: true

require_relative "../config/environment"

user = User.first
client = Ollama::Client.new

system_prompt = "You are a helpful assistant. Use tools when appropriate."
message = "Spent 300 on groceries paid via cash today"

tools = [
  {
    type: "function",
    function: {
      name: "create_expense",
      description: "Log a new expense",
      parameters: {
        type: "object",
        properties: {
          amount: { type: "number" },
          category_name: { type: "string" },
          payment_method: { type: "string" },
          description: { type: "string" }
        },
        required: ["amount", "category_name", "payment_method", "description"]
      }
    }
  }
]

messages = [
  { role: "system", content: system_prompt },
  { role: "user", content: message }
]

response = client.chat(messages: messages, tools: tools)

# Let's build format A: passing tc.arguments as Hash
assistant_msg_a = {
  role: "assistant",
  content: response.message.content || "",
  tool_calls: response.message.tool_calls.map do |tc|
    {
      id: tc.id,
      type: "function",
      function: { name: tc.name, arguments: tc.arguments } # Hash
    }
  end
}

# Let's execute tool
tool_msg = {
  role: "tool",
  tool_call_id: response.message.tool_calls.first.id,
  name: response.message.tool_calls.first.name,
  content: { success: true, message: "Logged" }.to_json
}

messages_a = messages + [assistant_msg_a, tool_msg]

puts "--- SENDING WITH FORMAT A (Hash arguments) ---"
begin
  res_a = client.chat(messages: messages_a, tools: tools)
  puts "Success! Response:"
  puts res_a.message.content
rescue => e
  puts "Failed with format A: #{e.class} - #{e.message}"
end

# Let's build format B: passing tc.arguments.to_json
assistant_msg_b = {
  role: "assistant",
  content: response.message.content || "",
  tool_calls: response.message.tool_calls.map do |tc|
    {
      id: tc.id,
      type: "function",
      function: { name: tc.name, arguments: tc.arguments.to_json } # JSON String
    }
  end
}

messages_b = messages + [assistant_msg_b, tool_msg]

puts "\n--- SENDING WITH FORMAT B (JSON String arguments) ---"
begin
  res_b = client.chat(messages: messages_b, tools: tools)
  puts "Success! Response:"
  puts res_b.message.content
rescue => e
  puts "Failed with format B: #{e.class} - #{e.message}"
end
