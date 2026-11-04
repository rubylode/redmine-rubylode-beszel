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

# Where the block shows besides the macro, the page and the My page block: the welcome page, the project Overview page,
# the pages matching the path list (My page included) and the top menu.
class RubylodeBeszel::PlacementsTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :news, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :issues, :versions

  BLOCK = ".rubylode-beszel".freeze

  setup do
    use_memory_cache
    configure_plugin
    publish_systems([hub_record("web-1"), hub_record("db-1", status: "down")])
  end

  teardown do
    restore_cache
  end

  test "no placement is on by default" do
    log_user("jsmith", "jsmith")
    %w[/ /my/page /projects/ecookbook /issues].each do |path|
      get path
      assert_response :success
      assert_select BLOCK, 0, "unexpected block on #{path}"
    end
    assert_select "#top-menu a", text: "Servers", count: 0
  end

  test "welcome page: right column by default, left when chosen, with the stylesheet in the head" do
    configure_plugin("show_on_welcome_page" => "1")
    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".splitcontentright #{BLOCK} .rubylode-beszel-summary", text: "1 of 2 down"
    assert_select ".splitcontentleft #{BLOCK}", 0
    assert_select "head link[href*=?]", "rubylode_beszel"

    configure_plugin("show_on_welcome_page" => "1", "welcome_page_column" => "left")
    get "/"
    assert_select ".splitcontentleft #{BLOCK}"
    assert_select ".splitcontentright #{BLOCK}", 0
  end

  test "project Overview page: right column by default, left when chosen" do
    configure_plugin("show_on_project_overview" => "1")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"

    assert_select ".splitcontentright #{BLOCK} .rubylode-beszel-summary", text: "1 of 2 down"
    assert_select ".splitcontentleft #{BLOCK}", 0

    configure_plugin("show_on_project_overview" => "1", "project_overview_column" => "left")
    get "/projects/ecookbook"
    assert_select ".splitcontentleft #{BLOCK}"
  end

  test "My page: the default layout has the block for a person who has not arranged their own" do
    configure_plugin("show_on_my_page" => "1")
    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select "#block-rubylode_beszel_status #{BLOCK} .rubylode-beszel-summary", text: "1 of 2 down"
    assert_select BLOCK, 1
  end

  test "My page: a person with their own arrangement keeps it, and can still add the block" do
    configure_plugin("show_on_my_page" => "1")
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => [], "left" => ["issuesassignedtome"], "right" => [] }
    preference.save!

    log_user("jsmith", "jsmith")
    get "/my/page"
    assert_select BLOCK, 0
    assert_includes Redmine::MyPage.block_options.map(&:last), "rubylode_beszel_status"
  end

  test "My page: without the box the default layout does not have the block" do
    refute_includes Redmine::MyPage.default_layout.values.flatten, "rubylode_beszel_status"
  end

  test "My page: with the box the default layout has the block once" do
    configure_plugin("show_on_my_page" => "1")

    assert_equal 1, Redmine::MyPage.default_layout.values.flatten.count("rubylode_beszel_status")
  end

  test "My page with the box checked and the block in the person's own layout shows it once" do
    configure_plugin("show_on_my_page" => "1")
    preference = User.find(2).pref
    preference.my_page_layout = { "top" => ["rubylode_beszel_status"] }
    preference.save!

    log_user("jsmith", "jsmith")
    get "/my/page"

    assert_select BLOCK, 1
    assert_select "#block-rubylode_beszel_status #{BLOCK}", 1
  end

  test "a listed path draws the small block on the matching pages only" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/issues\n/projects/*/issues")
    log_user("jsmith", "jsmith")

    get "/issues"
    assert_select "#{BLOCK}.is-compact .rubylode-beszel-summary", text: "1 of 2 down"
    assert_select "head link[href*=?]", "rubylode_beszel"
    get "/issues?set_filter=1&status_id=o"
    assert_select "#{BLOCK}.is-compact", 1
    get "/projects/ecookbook/issues"
    assert_select "#{BLOCK}.is-compact", 1
    get "/projects/ecookbook"
    assert_select BLOCK, 0
    get "/news"
    assert_select BLOCK, 0
  end

  test "the compact block leaves out the description and last seen columns by css class, and keeps the bars" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/issues")
    log_user("jsmith", "jsmith")
    get "/issues"

    assert_select "#{BLOCK}.is-compact .rubylode-beszel-bar", 6
  end

  test "a wildcard for everything does not reach the settings page or the sign-in page" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/*")

    get "/login"
    assert_response :success
    assert_select BLOCK, 0

    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_beszel"
    assert_response :success
    assert_select "#content #{BLOCK}", 0
    get "/admin"
    assert_select BLOCK, 0
    get "/issues"
    assert_select BLOCK, 1
  end

  test "a protected path listed explicitly does get the block" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/login")

    get "/login"
    assert_select BLOCK, 0, "an anonymous visitor is never shown the block"

    log_user("admin", "admin")
    get "/settings/plugin/redmine_rubylode_beszel"
    assert_select BLOCK, 0
  end

  test "a page that already has the block through the macro does not get a second one from the path list" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/projects/*")
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Status_once")
    page.content = WikiContent.new(text: "{{beszel_status}}", author: User.find(2))
    page.save!

    log_user("jsmith", "jsmith")
    get "/projects/ecookbook/wiki/Status_once"

    assert_select BLOCK, 1
  end

  test "the standalone page with its own path in the list is not doubled" do
    configure_plugin("show_on_matching_pages" => "1", "matching_page_paths" => "/status/beszel")
    log_user("jsmith", "jsmith")
    get "/status/beszel"

    assert_select BLOCK, 1
  end

  test "every placement honours the who-may-see-it setting" do
    configure_plugin("show_on_welcome_page" => "1", "show_on_project_overview" => "1", "show_on_my_page" => "1",
                     "show_on_matching_pages" => "1", "matching_page_paths" => "/issues", "show_in_top_menu" => "1", "visibility" => "admins")
    log_user("jsmith", "jsmith")
    %w[/ /projects/ecookbook /my/page /issues].each do |path|
      get path
      assert_select BLOCK, 0, "block shown on #{path}"
    end
    assert_select "#top-menu a", text: "Servers", count: 0

    post "/logout"
    log_user("admin", "admin")
    get "/"
    assert_select BLOCK, 1
    assert_select "#top-menu a[href=?]", "/status/beszel", text: "Servers"
  end

  test "every placement uses the cache: the hub is asked once for a page with several placements" do
    server = FakeBeszelHub.new(email: "a@example.com", password: "p").start
    ENV["BESZEL_EMAIL"] = "a@example.com"
    ENV["BESZEL_PASSWORD"] = "p"
    configure_plugin("base_url" => server.hub_url, "show_on_welcome_page" => "1", "show_on_matching_pages" => "1", "matching_page_paths" => "/")
    log_user("jsmith", "jsmith")
    3.times { get "/" }

    assert_equal 1, server.request_count
  ensure
    server&.stop
    ENV.delete("BESZEL_EMAIL")
    ENV.delete("BESZEL_PASSWORD")
  end

  test "an unconfigured plugin shows administrators the hint on a placement and everyone else nothing" do
    configure_plugin("base_url" => "", "show_on_welcome_page" => "1")
    log_user("jsmith", "jsmith")
    get "/"
    assert_select BLOCK, 0

    post "/logout"
    log_user("admin", "admin")
    get "/"
    assert_select "#{BLOCK} .rubylode-beszel-hint a[href=?]", "/settings/plugin/redmine_rubylode_beszel"
  end

  test "the top menu link appears only when the setting is on, named like the block title" do
    configure_plugin("show_in_top_menu" => "1", "block_title" => "Company servers")
    log_user("jsmith", "jsmith")
    get "/"

    assert_select "#top-menu a[href=?]", "/status/beszel", text: "Company servers"
  end

  test "the wiki preview carries the stylesheet itself because it has no head" do
    log_user("jsmith", "jsmith")
    post "/projects/ecookbook/wiki/Preview_page/preview", params: { content: { text: "{{beszel_status}}" } }, xhr: true

    assert_response :success
    assert_select "link[href*=?]", "rubylode_beszel"
    assert_select BLOCK, 1
  end

  test "the welcome text renders the macro" do
    Setting.welcome_text = "Hello\n\n{{beszel_status}}"
    log_user("jsmith", "jsmith")
    get "/"

    assert_select ".wiki #{BLOCK} .rubylode-beszel-summary", text: "1 of 2 down"
  ensure
    Setting.welcome_text = ""
  end

  test "news and project descriptions render the macro" do
    project = Project.find(1)
    project.update_column(:description, "{{beszel_status}}")
    log_user("jsmith", "jsmith")
    get "/projects/ecookbook"

    assert_select ".wiki #{BLOCK}", 1
  end
end
