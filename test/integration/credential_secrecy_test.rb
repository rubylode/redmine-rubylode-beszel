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

# The email, the password and the token the hub returns are never stored, rendered, logged or put in an error message,
# and the plugin only reads environment variables named BESZEL_*.
class RubylodeBeszel::CredentialSecrecyTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  SAMPLE_EMAIL = "hub-user-DO-NOT-LEAK@example.com".freeze
  SAMPLE_PASSWORD = "sample-password-DO-NOT-LEAK-7f3a91".freeze
  EMAIL_VARIABLE = "BESZEL_SECRECY_TEST_EMAIL".freeze
  PASSWORD_VARIABLE = "BESZEL_SECRECY_TEST_PASSWORD".freeze

  setup do
    use_memory_cache
    @server = FakeBeszelHub.new(email: SAMPLE_EMAIL, password: SAMPLE_PASSWORD).start
    @other = FakeBeszelHub.new(email: SAMPLE_EMAIL, password: SAMPLE_PASSWORD).start
    ENV[EMAIL_VARIABLE] = SAMPLE_EMAIL
    ENV[PASSWORD_VARIABLE] = SAMPLE_PASSWORD
    configure_plugin("base_url" => @server.hub_url, "email_environment_variable" => EMAIL_VARIABLE,
                     "password_environment_variable" => PASSWORD_VARIABLE, "cache_seconds" => "60")
    @log_path = Rails.root.join("log", "#{Rails.env}.log")
    @log_offset = File.exist?(@log_path) ? File.size(@log_path) : 0
  end

  teardown do
    [EMAIL_VARIABLE, PASSWORD_VARIABLE, "SECRET_KEY_BASE", "DATABASE_PASSWORD"].each { |name| ENV.delete(name) }
    @server.stop
    @other.stop
    restore_cache
  end

  def log_written_during_test
    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    return "" unless File.exist?(@log_path)

    File.open(@log_path) { |file| file.seek(@log_offset); file.read.to_s }
  end

  def refute_leaks(*secrets)
    secrets.each do |secret|
      refute_includes response.body, secret
      refute_includes log_written_during_test, secret
    end
  end

  test "with the right credentials the page works and no credential is in the html or the log" do
    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "All servers up"
    refute_leaks SAMPLE_EMAIL, SAMPLE_PASSWORD, FakeBeszelHub::TOKEN
  end

  test "with a wrong password the page says unavailable and neither the html, the log nor the reason shows any credential" do
    ENV[PASSWORD_VARIABLE] = "wrong-password-also-secret-55"

    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
    assert_select ".rubylode-beszel-hint", text: /refused the sign-in/
    refute_leaks SAMPLE_EMAIL, SAMPLE_PASSWORD, "wrong-password-also-secret-55"
  end

  test "the settings page and the saved settings never hold a credential" do
    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_beszel"
    refute_includes response.body, SAMPLE_PASSWORD
    refute_includes response.body, SAMPLE_EMAIL
    assert_select "strong", text: "set in the environment", count: 2

    post "/settings/plugin/redmine_rubylode_beszel", params: { settings: Setting.send(:"plugin_#{PLUGIN_ID}") }
    [SAMPLE_PASSWORD, SAMPLE_EMAIL].each do |secret|
      assert_empty Setting.where("value LIKE ?", "%#{secret}%").to_a
    end
  end

  test "the hub is asked once for two page loads within the cache window" do
    log_user("jsmith", "jsmith")
    2.times { get "/status/beszel" }

    assert_equal 1, @server.request_count
    assert_equal 1, @server.sign_in_count
  end

  test "a variable outside the BESZEL_ prefix is ignored at runtime: the credential counts as missing and the hub is never asked" do
    ENV["SECRET_KEY_BASE"] = SAMPLE_PASSWORD
    configure_plugin("base_url" => @server.hub_url, "email_environment_variable" => EMAIL_VARIABLE,
                     "password_environment_variable" => "SECRET_KEY_BASE")

    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
    assert_equal 0, @server.sign_in_count
    assert_empty @server.seen_requests
    refute_leaks SAMPLE_PASSWORD
  end

  test "DATABASE_PASSWORD as the email variable is ignored at runtime as well" do
    ENV["DATABASE_PASSWORD"] = SAMPLE_EMAIL
    configure_plugin("base_url" => @server.hub_url, "email_environment_variable" => "DATABASE_PASSWORD",
                     "password_environment_variable" => PASSWORD_VARIABLE)

    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
    assert_empty @server.seen_requests
  end

  test "a redirect to another host never receives the credentials, and the page says unavailable" do
    @server.redirect_to = "http://localhost:#{@other.port}"

    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
    assert_select ".rubylode-beszel-hint", text: /not allowed/
    assert_empty @other.seen_requests, "the other host received nothing"
    refute_leaks SAMPLE_PASSWORD, SAMPLE_EMAIL
  end

  test "a plain http hub that is not loopback and not allowed is never sent credentials" do
    configure_plugin("base_url" => "http://beszel.example.com", "email_environment_variable" => EMAIL_VARIABLE,
                     "password_environment_variable" => PASSWORD_VARIABLE)

    log_user("admin", "admin")
    get "/status/beszel"

    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
    assert_select ".rubylode-beszel-hint", text: /not https/
  end
end
