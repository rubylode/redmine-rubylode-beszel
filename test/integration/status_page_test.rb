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

class RubylodeBeszel::StatusPageTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issue_statuses, :trackers, :projects_trackers, :enumerations, :enabled_modules

  setup do
    use_memory_cache
    configure_plugin
  end

  teardown do
    restore_cache
  end

  def hub_failure(reason = "The Beszel hub answered 503")
    RubylodeBeszel::SystemStatus.cache.write(RubylodeBeszel::SystemStatus.cache_key_for("https://beszel.example.com"), { "failure" => reason })
  end

  test "the page shows a table of servers with status, last seen and usage bars, down ones first" do
    publish_systems([hub_record("web-1", cpu: 23.4, memory: 41.8, disk: 52.1), hub_record("db-1", status: "down"), hub_record("backup-1", disk: 93.4)])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_response :success
    assert_select ".rubylode-beszel-summary.is-has-down", text: "1 of 3 down"
    assert_select "tbody tr:first-child.is-down td.rubylode-beszel-name", text: "Database"
    assert_select "tr.is-up td.rubylode-beszel-description", text: "The public site"
    assert_select "tr.is-up td.rubylode-beszel-state", text: "Up"
    assert_select "tr.is-down td.rubylode-beszel-state", text: "Down"
    assert_select "tr.is-up td.rubylode-beszel-last-seen", text: /ago/
    assert_select "tr.is-up .rubylode-beszel-bar[aria-label=CPU][aria-valuenow=23]"
    assert_select "tr.is-up .rubylode-beszel-bar[aria-label=Memory][aria-valuenow=42]"
    assert_select "tr.is-up .rubylode-beszel-bar[aria-label=Disk][aria-valuenow=52].is-normal"
    assert_select ".rubylode-beszel-bar.is-critical[aria-label=Disk][aria-valuenow=93]"
    assert_select ".rubylode-beszel-bar-fill[style=?]", "width: 93%"
  end

  test "a warning-level reading gets the warning bar" do
    publish_systems([hub_record("web-1", cpu: 84.0)])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select ".rubylode-beszel-bar.is-warning[aria-label=CPU]"
  end

  test "every server up gives the all-up summary and no down rows" do
    publish_systems([hub_record("web-1"), hub_record("db-1"), hub_record("backup-1")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select ".rubylode-beszel-summary.is-all-up", text: "All servers up"
    assert_select "tr.is-down", 0
  end

  test "a system the hub has but the list leaves out does not appear" do
    publish_systems([hub_record("web-1"), hub_record("staging-1", status: "down")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select ".rubylode-beszel-table", text: /staging-1/, count: 0
  end

  test "a system without readings shows dashes" do
    publish_systems([hub_record("web-1", cpu: nil, memory: nil, disk: nil)])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select "tr.is-up td.rubylode-beszel-usage", text: "–", count: 3
  end

  test "with no list in the settings every system of the hub is shown" do
    configure_plugin("systems" => "")
    publish_systems([hub_record("web-1"), hub_record("staging-1")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select "td.rubylode-beszel-name", text: "staging-1"
    assert_select "td.rubylode-beszel-name", text: "web-1"
  end

  test "the block title is the setting" do
    configure_plugin("block_title" => "Company servers")
    publish_systems([hub_record("web-1")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select "h2", text: "Company servers"
  end

  test "when the hub gives no answer the page still renders with status unavailable, and the reason is for administrators" do
    hub_failure

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_response :success
    assert_select ".rubylode-beszel-summary.is-unavailable", text: "Status unavailable"
    assert_select ".rubylode-beszel-table", 0
    assert_select ".rubylode-beszel-hint", 0

    post "/logout"
    log_user("admin", "admin")
    get "/beszel_status"
    assert_select ".rubylode-beszel-hint", text: /answered 503/
  end

  test "missing credentials show status unavailable and the page renders" do
    ENV.delete("BESZEL_EMAIL")
    ENV.delete("BESZEL_PASSWORD")
    configure_plugin("hub_url" => "http://127.0.0.1:9")

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_response :success
    assert_select ".rubylode-beszel-summary", text: "Status unavailable"
  end

  test "not configured: administrators get a hint with a link to the settings, everyone else gets an empty page" do
    configure_plugin("hub_url" => "")

    log_user("admin", "admin")
    get "/beszel_status"
    assert_select ".rubylode-beszel-hint a[href=?]", "/settings/plugin/redmine_rubylode_beszel"

    post "/logout"
    log_user("jsmith", "jsmith")
    get "/beszel_status"
    assert_response :success
    assert_select ".rubylode-beszel", 0
  end

  test "an anonymous visitor is sent to sign in" do
    get "/beszel_status"

    assert_redirected_to %r{/login}
  end

  test "the stylesheet is linked from the page head" do
    publish_systems([hub_record("web-1")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_select "head link[href*=?]", "rubylode_beszel"
  end

  test "administrators only: other people are refused, administrators see the page" do
    configure_plugin("visibility" => "admins")
    publish_systems([hub_record("web-1")])

    log_user("jsmith", "jsmith")
    get "/beszel_status"
    assert_response :forbidden

    post "/logout"
    log_user("admin", "admin")
    get "/beszel_status"
    assert_response :success
    assert_select ".rubylode-beszel-summary"
  end
end
