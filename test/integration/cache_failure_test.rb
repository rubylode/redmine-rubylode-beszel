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

# A status block never takes a page down: a cache store that raises, or a status object that raises, still gives a 200.
class RubylodeBeszel::CacheFailureTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :issues, :versions, :news, :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions

  SUMMARY = ".rubylode-beszel-summary".freeze
  EMAIL = "hub-user-DO-NOT-LEAK@example.com".freeze
  PASSWORD = "cache-failure-password-5c1d88".freeze
  EMAIL_VARIABLE = "BESZEL_CACHE_FAILURE_TEST_EMAIL".freeze
  PASSWORD_VARIABLE = "BESZEL_CACHE_FAILURE_TEST_PASSWORD".freeze

  setup do
    use_memory_cache
    @server = FakeBeszelHub.new(email: EMAIL, password: PASSWORD).start
    ENV[EMAIL_VARIABLE] = EMAIL
    ENV[PASSWORD_VARIABLE] = PASSWORD
    configure_plugin("hub_url" => @server.hub_url, "email_environment_variable" => EMAIL_VARIABLE,
                     "password_environment_variable" => PASSWORD_VARIABLE, "show_on_welcome_page" => "1")
  end

  teardown do
    [EMAIL_VARIABLE, PASSWORD_VARIABLE].each { |name| ENV.delete(name) }
    @server.stop
    restore_cache
  end

  def raising_status(&block)
    replacing_method(RubylodeBeszel::SystemStatus, :current, ->(*) { raise IOError, "status object broke" }, &block)
  end

  test "the welcome page answers 200 with the block when the cache store raises" do
    RubylodeBeszel::SystemStatus.cache = RubylodeBeszelTestHelpers::UnwritableCache.new

    log_user("jsmith", "jsmith")
    get "/"

    assert_response :success
    assert_select "#{SUMMARY}.is-all-up", text: "All servers up"
  end

  test "the hub credentials are not in the log line written for a cache failure" do
    RubylodeBeszel::SystemStatus.cache = RubylodeBeszelTestHelpers::UnwritableCache.new

    log_user("jsmith", "jsmith")
    log = captured_log { get "/" }

    assert_includes log, "Rubylode Beszel: cache read failed"
    [EMAIL, PASSWORD].each do |secret|
      refute_includes log, secret
      refute_includes response.body, secret
    end
  end

  test "the welcome page answers 200 with status unavailable when the status object raises" do
    log_user("jsmith", "jsmith")
    raising_status { get "/" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable", text: "Status unavailable"
  end

  test "My page answers 200 with status unavailable when the status object raises" do
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => ["rubylode_beszel_status"] }
    preference.save!

    log_user("jsmith", "jsmith")
    raising_status { get "/my/page" }

    assert_response :success
    assert_select "#block-rubylode_beszel_status #{SUMMARY}.is-unavailable"
  end

  test "the project overview answers 200 with status unavailable when the status object raises" do
    configure_plugin("hub_url" => @server.hub_url, "show_on_project_overview" => "1")

    log_user("jsmith", "jsmith")
    raising_status { get "/projects/ecookbook" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "a page on the path list answers 200 with status unavailable when the status object raises" do
    configure_plugin("hub_url" => @server.hub_url, "show_on_paths" => "/issues")

    log_user("jsmith", "jsmith")
    raising_status { get "/issues" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "a wiki page with the macro answers 200 with status unavailable when the status object raises" do
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Status_#{SecureRandom.hex(3)}")
    page.content = WikiContent.new(text: "{{beszel_status}}", author: User.find(2))
    page.save!

    log_user("jsmith", "jsmith")
    raising_status { get "/projects/ecookbook/wiki/#{page.title}" }

    assert_response :success
    assert_select ".wiki #{SUMMARY}.is-unavailable"
  end

  test "the standalone page answers 200 with status unavailable when the status object raises" do
    log_user("jsmith", "jsmith")
    raising_status { get "/beszel_status" }

    assert_response :success
    assert_select "#{SUMMARY}.is-unavailable"
  end

  test "an administrator sees the class name of the error in the hint, others do not" do
    log_user("admin", "admin")
    raising_status { get "/beszel_status" }
    assert_select ".rubylode-beszel-hint", text: /IOError/

    post "/logout"
    log_user("jsmith", "jsmith")
    raising_status { get "/beszel_status" }
    assert_select ".rubylode-beszel-hint", 0
  end
end
