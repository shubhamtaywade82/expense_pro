class Rack::Attack
  throttle("auth/login", limit: 10, period: 60) do |req|
    if req.path == "/api/v1/session" && req.post?
      req.ip
    end
  end

  throttle("auth/register", limit: 3, period: 300) do |req|
    if req.path == "/api/v1/registrations" && req.post?
      req.ip
    end
  end

  throttle("api/requests", limit: 300, period: 60) do |req|
    if req.path.start_with?("/api/")
      req.ip
    end
  end
end
