class Rack::Attack
  throttle("logins/ip", limit: 5, period: 60) do |req|
    req.ip if req.path == "/api/v1/session" && req.post?
  end

  throttle("registrations/ip", limit: 3, period: 300) do |req|
    req.ip if req.path == "/api/v1/registrations" && req.post?
  end

  throttle("api/ip", limit: 100, period: 60) do |req|
    req.ip if req.path.start_with?("/api/v1/")
  end
end
