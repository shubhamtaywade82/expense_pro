require "test_helper"

class Api::V1::AiControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # Log in and obtain JWT
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "should get assistant response from chat endpoint" do
    mock_service = Object.new
    def mock_service.chat(*_args)
      { role: "assistant", content: "Hello! How can I help you today?" }
    end

    original_new = AiChatService.method(:new)
    AiChatService.define_singleton_method(:new) { |*| mock_service }

    begin
      post api_v1_ai_chat_url, params: { message: "Hello AI" }, headers: @headers
      assert_response :success

      json = JSON.parse(response.body)
      assert_equal "assistant", json["role"]
      assert_equal "Hello! How can I help you today?", json["content"]
    ensure
      AiChatService.define_singleton_method(:new, &original_new)
    end
  end
end
