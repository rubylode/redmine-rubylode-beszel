# Rubylode Beszel: server status from a Beszel hub for Redmine
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require "socket"
require "json"
require "time"

# A tiny stand-in for a Beszel hub (a PocketBase app), for the demo and the integration tests. Standard library only.
#
# It answers the two calls the plugin makes, with the same JSON shapes PocketBase uses:
#
#   POST /api/collections/users/auth-with-password   {"identity": email, "password": password}
#        200 {"token": "...", "record": {...}} for the right pair, 400 otherwise
#   GET  /api/collections/systems/records            the Authorization header must carry the token (raw or "Bearer ...")
#        200 {"page": 1, "perPage": 500, "totalItems": n, "totalPages": 1, "items": [...]}, 401 without the token
#
# What the systems report depends on the scenario:
#
#   all_up       every system up (one disk is nearly full, to show the warning bar)
#   one_down     "db-1" down, last seen two hours ago
#   unavailable  503, as if the hub were broken
#
# POST /__redirect_to (body: a base URL, or empty to clear it) makes the hub answer its /api requests with a 302 to that base,
# which is how the tests check that credentials never follow a redirect to another host.
# POST /__scenario/<name> switches the scenario; GET /__requests returns how many times the systems were listed, and
# GET /__sign_ins how many times the hub was signed in to.
# Run it on its own:  FAKE_BESZEL_EMAIL=a@example.com FAKE_BESZEL_PASSWORD=some-password ruby test/support/fake_beszel_hub.rb
class FakeBeszelHub
  TOKEN = "fake.hub.token-not-a-secret".freeze

  # name => [cpu, memory, disk, seconds since the hub last heard from it]. "staging-1" is one curated lists leave out.
  SYSTEMS = {
    "web-1" => [23.4, 41.8, 52.1, 12],
    "db-1" => [61.0, 78.5, 66.2, 9],
    "backup-1" => [4.2, 18.9, 93.4, 15],
    "worker-1" => [88.7, 71.3, 44.0, 7],
    "staging-1" => [2.1, 12.5, 30.8, 20]
  }.freeze

  SCENARIOS = %w[all_up one_down unavailable].freeze

  attr_reader :port, :request_count, :sign_in_count, :seen_requests
  attr_accessor :redirect_to
  attr_accessor :scenario

  def initialize(email:, password:, port: 0, scenario: "all_up", host: "127.0.0.1")
    @email = email
    @password = password
    @host = host
    @requested_port = port
    @scenario = scenario
    @request_count = 0
    @sign_in_count = 0
    @seen_requests = []
  end

  def start
    @server = TCPServer.new(@host, @requested_port)
    @port = @server.addr[1]
    @thread = Thread.new { accept_loop }
    self
  end

  def stop
    @server&.close
    @thread&.join(2)
  end

  def hub_url
    "http://#{@host}:#{@port}"
  end

  def items
    SYSTEMS.map do |name, (cpu, memory, disk, seconds_ago)|
      down = scenario == "one_down" && name == "db-1"
      seconds_ago = 7200 if down
      { "id" => name.delete("-").ljust(15, "0")[0, 15], "name" => name, "status" => down ? "down" : "up",
        "updated" => (Time.now.utc - seconds_ago).strftime("%Y-%m-%d %H:%M:%S.%LZ"),
        "info" => { "cpu" => cpu, "mp" => memory, "dp" => disk, "u" => 864_000, "v" => "0.12.0" } }
    end
  end

  private

  def accept_loop
    loop do
      client = @server.accept
      Thread.new(client) { |connection| handle(connection) }
    rescue IOError, Errno::EBADF
      break
    end
  end

  def handle(client)
    request_line = client.gets.to_s
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.downcase] = value.to_s.strip
    end
    body = headers["content-length"] ? client.read(headers["content-length"].to_i).to_s : ""
    method, path = request_line.split(" ")
    status, payload = respond(method, path.to_s, headers, body)
    client.write("HTTP/1.1 #{status}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
  rescue StandardError
    nil
  ensure
    client.close
  end

  def respond(method, path, headers, body)
    route = path.split("?").first
    @seen_requests << { path: path, headers: headers, body: body } unless route.start_with?("/__")
    if method == "POST" && route.start_with?("/__scenario/")
      switch_scenario(route.delete_prefix("/__scenario/"))
    elsif method == "POST" && route == "/__redirect_to"
      self.redirect_to = body.strip.empty? ? nil : body.strip
      ["200 OK", "ok"]
    elsif redirect_to && route.start_with?("/api/")
      ["302 Found\r\nLocation: #{redirect_to}#{path}", ""]
    elsif route == "/__requests"
      ["200 OK", "#{request_count}\n"]
    elsif route == "/__sign_ins"
      ["200 OK", "#{sign_in_count}\n"]
    elsif method == "POST" && route == "/api/collections/users/auth-with-password"
      sign_in(body)
    elsif method == "GET" && route == "/api/collections/systems/records"
      list_systems(headers["authorization"])
    else
      ["404 Not Found", JSON.generate("status" => 404, "message" => "The requested resource wasn't found.", "data" => {})]
    end
  end

  def switch_scenario(name)
    return ["404 Not Found", JSON.generate("message" => "unknown scenario")] unless SCENARIOS.include?(name)

    self.scenario = name
    ["200 OK", JSON.generate("scenario" => name)]
  end

  def sign_in(body)
    @sign_in_count += 1
    return ["503 Service Unavailable", JSON.generate("message" => "the hub is unwell")] if scenario == "unavailable"

    credentials = JSON.parse(body) rescue {}
    if credentials["identity"] == @email && credentials["password"] == @password
      ["200 OK", JSON.generate("token" => TOKEN, "record" => { "id" => "user0000000001", "collectionName" => "users", "email" => @email })]
    else
      ["400 Bad Request", JSON.generate("status" => 400, "message" => "Failed to authenticate.", "data" => {})]
    end
  end

  def list_systems(authorization)
    @request_count += 1
    return ["503 Service Unavailable", JSON.generate("message" => "the hub is unwell")] if scenario == "unavailable"
    return ["401 Unauthorized", JSON.generate("status" => 401, "message" => "The request requires valid record authorization token.", "data" => {})] unless authorization.to_s.delete_prefix("Bearer ") == TOKEN

    records = items
    ["200 OK", JSON.generate("page" => 1, "perPage" => 500, "totalItems" => records.size, "totalPages" => 1, "items" => records)]
  end
end

if $PROGRAM_NAME == __FILE__
  server = FakeBeszelHub.new(email: ENV.fetch("FAKE_BESZEL_EMAIL"), password: ENV.fetch("FAKE_BESZEL_PASSWORD"),
                             port: ENV.fetch("FAKE_BESZEL_PORT", "8090").to_i, host: "0.0.0.0",
                             scenario: ENV.fetch("FAKE_BESZEL_SCENARIO", "all_up")).start
  puts "Fake Beszel hub on port #{server.port}, scenario #{server.scenario}"
  $stdout.flush
  sleep
end
