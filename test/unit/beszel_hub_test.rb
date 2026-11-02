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

require_relative "../test_helper"

class RubylodeBeszel::BeszelHubTest < ActiveSupport::TestCase
  EMAIL = "monitor@example.com".freeze
  PASSWORD = "hub-password-DO-NOT-LEAK-91".freeze

  setup do
    @server = FakeBeszelHub.new(email: EMAIL, password: PASSWORD).start
    @other = FakeBeszelHub.new(email: EMAIL, password: PASSWORD).start
  end

  teardown do
    @server.stop
    @other.stop
  end

  def hub(url: @server.hub_url, email: EMAIL, password: PASSWORD, **options)
    RubylodeBeszel::BeszelHub.new(url: url, email: email, password: password, **options)
  end

  test "signs in and lists the systems as plain hashes" do
    records = hub.call

    assert_equal %w[backup-1 db-1 staging-1 web-1 worker-1], records.map { |record| record["name"] }.sort
    web = records.find { |record| record["name"] == "web-1" }
    assert_equal "up", web["status"]
    assert_equal [23.4, 41.8, 52.1], [web["cpu"], web["memory"], web["disk"]]
    assert_match(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d/, web["updated"])
    assert_equal 1, @server.sign_in_count
    assert_equal 1, @server.request_count
  end

  test "keeps only the fields the page needs" do
    assert_equal %w[cpu disk memory name status updated], hub.call.first.keys.sort
  end

  test "asks the hub only for the fields it shows, so a server's address is never fetched" do
    hub.call

    assert_match(/fields=name,status,updated,info/, @server.seen_requests.last[:path])
  end

  test "a wrong password is reported as a refused sign-in and the password is not in the message" do
    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(password: "wrong-password-55").call }

    assert_equal "The Beszel hub refused the sign-in", error.message
  end

  test "a broken hub is reported with its status" do
    @server.scenario = "unavailable"

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub.call }
    assert_match(/answered 503/, error.message)
  end

  test "missing credentials make no request and name the variables" do
    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) do
      hub(email: "", credential_names: %w[BESZEL_EMAIL BESZEL_PASSWORD]).call
    end

    assert_match(/BESZEL_EMAIL, BESZEL_PASSWORD/, error.message)
    assert_equal 0, @server.sign_in_count
  end

  test "nothing listening is reported as unreachable, with the error class only" do
    port = @server.port
    @server.stop

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(url: "http://127.0.0.1:#{port}").call }
    assert_match(/could not be reached \(/, error.message)
  end

  test "an error carrying a credential in its own message is scrubbed" do
    client = ->(*) { raise RubylodeBeszel::BeszelHub::Unavailable, "boom #{PASSWORD} for #{EMAIL}" }

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(http_client: client).call }
    refute_includes error.message, PASSWORD
    refute_includes error.message, EMAIL
  end

  test "an unreadable answer is reported, not raised as a parse error" do
    client = ->(*) { [200, "<html>not json</html>", nil] }

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(http_client: client).call }
    assert_match(/could not be read/, error.message)
  end

  test "a record without info gives empty readings" do
    calls = 0
    client = lambda do |*|
      calls += 1
      calls == 1 ? [200, '{"token":"t"}', nil] : [200, '{"items":[{"name":"x","status":"pending"}]}', nil]
    end

    record = hub(http_client: client).call.first
    assert_equal ["x", "pending", nil, nil, nil], [record["name"], record["status"], record["cpu"], record["memory"], record["disk"]]
  end

  test "a plain http hub that is not loopback is refused before anything is sent" do
    sent = []
    client = ->(*arguments) { sent << arguments; [200, "{}", nil] }

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(url: "http://beszel.example.com", http_client: client).call }
    assert_match(/not https/, error.message)
    assert_empty sent
  end

  test "a plain http hub is used when the setting allows it" do
    client = ->(*) { [200, '{"token":"t","items":[]}', nil] }

    assert_equal [], hub(url: "http://beszel.example.com", allow_plain_http: true, http_client: client).call
  end

  test "a redirect to another host never receives the credentials" do
    @server.redirect_to = "http://localhost:#{@other.port}"

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub.call }

    assert_match(/redirected to a host that is not allowed/, error.message)
    assert_empty @other.seen_requests
  end

  test "a redirect to a host on the allowed list is followed" do
    @server.redirect_to = "http://localhost:#{@other.port}"

    records = hub(allowed_hosts: ["localhost"]).call

    assert_equal 5, records.size
    assert_equal 2, @other.seen_requests.size
  end

  test "a redirect to an http host is refused when plain http is not allowed for it" do
    client = ->(*) { [302, "", "http://beszel.example.com/api"] }

    error = assert_raises(RubylodeBeszel::BeszelHub::Unavailable) do
      hub(url: "https://beszel.example.com", http_client: client).call
    end
    assert_match(/redirected/, error.message)
  end

  test "an endless redirect stops" do
    client = ->(*) { [302, "", "/again"] }

    assert_raises(RubylodeBeszel::BeszelHub::Unavailable) { hub(http_client: client).call }
  end

  test "from_configuration reads the BESZEL_ variables and nothing else" do
    ENV["BESZEL_TEST_EMAIL"] = EMAIL
    ENV["BESZEL_TEST_PASSWORD"] = PASSWORD
    ENV["SECRET_KEY_BASE_FOR_TEST"] = "must-not-be-read"
    configuration = RubylodeBeszel::Configuration.new("hub_url" => @server.hub_url, "email_environment_variable" => "BESZEL_TEST_EMAIL",
                                                     "password_environment_variable" => "BESZEL_TEST_PASSWORD")

    assert_equal 5, RubylodeBeszel::BeszelHub.from_configuration(configuration).call.size
  ensure
    %w[BESZEL_TEST_EMAIL BESZEL_TEST_PASSWORD SECRET_KEY_BASE_FOR_TEST].each { |name| ENV.delete(name) }
  end

  test "a variable name outside the prefix is never read from the environment" do
    ENV["SECRET_KEY_BASE_FOR_TEST"] = "must-not-be-read"

    assert_equal "", RubylodeBeszel::BeszelHub.read_variable("SECRET_KEY_BASE_FOR_TEST")
    assert_equal "", RubylodeBeszel::BeszelHub.read_variable(nil)
  ensure
    ENV.delete("SECRET_KEY_BASE_FOR_TEST")
  end
end
