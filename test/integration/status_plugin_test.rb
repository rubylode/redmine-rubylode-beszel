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

# How the plugin behaves next to Rubylode Status: its own page path, the redirect from the old path, the top menu item, the
# notice, and the body the Status page asks the partial to draw.
class RubylodeBeszel::StatusPluginTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules

  SETTINGS_PATH = "/settings/plugin/redmine_rubylode_beszel".freeze
  NOTICE_INSTALLED = "Rubylode Status is installed, so this block shows on the Status page.".freeze
  NOTICE_MISSING = "Install Rubylode Status to see this with the other status blocks on one page.".freeze

  setup do
    use_memory_cache
    configure_plugin
    publish_systems([hub_record("web-1"), hub_record("db-1", status: "down")])
  end

  teardown do
    restore_cache
  end

  test "the page is at /status/beszel" do
    log_user("jsmith", "jsmith")
    get "/status/beszel"

    assert_response :success
    assert_select "h2", text: "Servers"
  end

  test "the old path /beszel_status redirects there with a 301" do
    log_user("jsmith", "jsmith")
    get "/beszel_status"

    assert_response :moved_permanently
    assert_redirected_to "/status/beszel"
  end

  test "the page and the settings page tell a missing Status plugin to be installed, with a link" do
    log_user("admin", "admin")
    [SETTINGS_PATH, "/status/beszel"].each do |path|
      get path

      assert_select "p.rubylode-status-notice", text: NOTICE_MISSING
      assert_select "p.rubylode-status-notice a[href=?]", "https://github.com/rubylode/redmine-rubylode-status", text: "Rubylode Status"
    end
  end

  test "with the Status plugin there the notice says the block is on the Status page" do
    log_user("admin", "admin")
    with_fake_status_registry do
      [SETTINGS_PATH, "/status/beszel"].each do |path|
        get path

        assert_select "p.rubylode-status-notice", text: NOTICE_INSTALLED
        assert_select "p.rubylode-status-notice a[href=?]", "/status", text: "Status page"
      end
    end
  end

  test "without the Status plugin the top menu item shows when asked for" do
    configure_plugin("show_in_top_menu" => "1")
    log_user("jsmith", "jsmith")
    get "/"

    assert_select "#top-menu a[href=?]", "/status/beszel", text: "Servers"
  end

  test "with the Status plugin the top menu item is gone even when asked for" do
    configure_plugin("show_in_top_menu" => "1")
    log_user("jsmith", "jsmith")
    with_fake_status_registry do
      get "/"

      assert_select "#top-menu a[href=?]", "/status/beszel", count: 0
    end
  end

  test "the top menu setting is on the settings page without the Status plugin, and hidden with it, keeping its saved value" do
    configure_plugin("show_in_top_menu" => "1")
    log_user("admin", "admin")
    get SETTINGS_PATH
    assert_select "input[type=checkbox][name=?][checked]", "settings[show_in_top_menu]"
    assert_select "label[for=settings_show_in_top_menu]", text: "Show in the top menu"

    with_fake_status_registry do
      get SETTINGS_PATH
      assert_select "input[type=checkbox][name=?]", "settings[show_in_top_menu]", 0
      assert_select "input[type=hidden][name=?][value=?]", "settings[show_in_top_menu]", "1"
    end
  end

  test "on the Status page the partial draws the table and leaves the title and the summary to the page" do
    User.current = User.find(2)
    html = ApplicationController.render(partial: "rubylode_beszel/status", locals: { widget: Object.new, status: Object.new }, assigns: {}, formats: [:html])

    assert_includes html, "rubylode-beszel-table"
    refute_includes html, "rubylode-beszel-summary"
    refute_includes html, "rubylode-beszel-title"
  ensure
    User.current = nil
  end
end
