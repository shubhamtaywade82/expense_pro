require "test_helper"
require "minitest/mock"

class Api::V1::AiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # Log in
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
  end

  test "should get assistant response from chat endpoint" do
    mock_response = Ollama::Response.new({
      "message" => {
        "role" => "assistant",
        "content" => "Hello! How can I help you today?"
      }
    })

    mock_client = Object.new
    mock_client.define_singleton_method(:chat) do |*args, **kwargs|
      mock_response
    end

    Ollama::Client.stub(:new, mock_client) do
      post api_v1_ai_chat_url, params: { message: "Hello AI" }
      assert_response :success
      
      json = JSON.parse(response.body)
      assert_equal "assistant", json["role"]
      assert_equal "Hello! How can I help you today?", json["content"]
    end
  end
end
