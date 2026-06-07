class FrontendController < ActionController::Base
  def index
    render file: Rails.root.join("public/frontend/index.html"), layout: false
  end
end
