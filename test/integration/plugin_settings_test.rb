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

class RubylodeBeszel::PluginSettingsTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  SETTINGS_PATH = "/settings/plugin/redmine_rubylode_beszel".freeze

  GOOD_SETTINGS = {
    "hub_url" => "https://beszel.example.com",
    "email_environment_variable" => "BESZEL_HUB_EMAIL",
    "password_environment_variable" => "BESZEL_HUB_PASSWORD",
    "allow_plain_http" => "0", "allowed_hosts" => "hub2.example.com",
    "systems" => "Web | web-1 | The site\nDatabase | db-1 | Primary",
    "cache_seconds" => "120", "failure_cache_seconds" => "15", "timeout_seconds" => "3",
    "block_title" => "Our servers", "visibility" => "admins"
  }.freeze

  setup do
    Setting.send(:"plugin_#{PLUGIN_ID}=", RedmineRubylodeBeszel::Defaults::SETTINGS.dup)
  end

  def saved
    Setting.send(:"plugin_#{PLUGIN_ID}")
  end

  test "the plugin is registered and its settings page opens with every field" do
    log_user("admin", "admin")
    get SETTINGS_PATH

    assert_response :success
    %w[hub_url email_environment_variable password_environment_variable allow_plain_http allowed_hosts systems block_title
       visibility cache_seconds failure_cache_seconds timeout_seconds].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
    assert_select "input[name=?][value=?]", "settings[email_environment_variable]", "BESZEL_EMAIL"
    assert_select "input[name=?][value=?]", "settings[password_environment_variable]", "BESZEL_PASSWORD"
  end

  test "good settings are saved as plugin settings" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }

    assert_redirected_to SETTINGS_PATH
    assert_equal "https://beszel.example.com", saved["hub_url"]
    assert_equal "BESZEL_HUB_EMAIL", saved["email_environment_variable"]
    assert_equal "admins", saved["visibility"]
    assert_equal 2, RubylodeBeszel::Configuration.current.systems.size
    assert_equal %w[hub2.example.com], RubylodeBeszel::Configuration.current.allowed_hosts
  end

  test "a bad server line shows the line error, keeps what was typed and saves nothing" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("systems" => "Web | web-1 | The site\nbroken line here") }

    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", text: /line 2/
    assert_select "textarea[name=?]", "settings[systems]", text: /broken line here/
    assert_equal "", saved["hub_url"], "nothing was saved"
  end

  test "an invalid hub url is refused" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("hub_url" => "ftp://nope") }

    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", 1
  end

  test "variables outside the BESZEL_ prefix are refused at save and nothing is saved" do
    log_user("admin", "admin")
    %w[SECRET_KEY_BASE DATABASE_PASSWORD].each do |name|
      post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("email_environment_variable" => name) }
      assert_response :unprocessable_entity
      assert_select "#errorExplanation li", text: /BESZEL_/

      post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("password_environment_variable" => name) }
      assert_response :unprocessable_entity
    end
    assert_equal "", saved["hub_url"]
  end

  test "a plain http hub is refused at save unless the box is ticked or the host is loopback" do
    log_user("admin", "admin")
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("hub_url" => "http://beszel.example.com") }
    assert_response :unprocessable_entity

    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("hub_url" => "http://beszel.example.com", "allow_plain_http" => "1") }
    assert_redirected_to SETTINGS_PATH
    assert RubylodeBeszel::Configuration.current.allow_plain_http?

    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS.merge("hub_url" => "http://localhost:8090") }
    assert_redirected_to SETTINGS_PATH
  end

  test "someone who is not an administrator cannot open or save the settings" do
    log_user("jsmith", "jsmith")

    get SETTINGS_PATH
    assert_response :forbidden
    post SETTINGS_PATH, params: { settings: GOOD_SETTINGS }
    assert_response :forbidden
    assert_equal "", saved["hub_url"]
  end

  test "the validation patch is applied to the settings controller" do
    assert SettingsController.include?(RedmineRubylodeBeszel::SettingsControllerPatch)
  end
end

class RubylodeBeszel::PluginSettingsHelpTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles

  PATH = "/settings/plugin/redmine_rubylode_beszel".freeze

  test "the settings page has every placement field" do
    log_user("admin", "admin")
    get PATH

    %w[show_on_welcome_page welcome_page_column show_on_my_page show_on_project_overview project_overview_column show_in_top_menu
       show_on_paths].each do |field|
      assert_select "[name=?]", "settings[#{field}]"
    end
  end

  test "the help explains every place with its macro, partial and page snippets" do
    log_user("admin", "admin")
    get PATH

    assert_select ".rubylode-beszel-help table tbody tr", 12
    assert_select ".rubylode-beszel-help th", text: "Where"
    assert_select ".rubylode-beszel-help pre", text: /\{\{beszel_status\}\}/
    assert_select ".rubylode-beszel-help pre", text: /render partial: "rubylode_beszel\/status"/
    assert_select ".rubylode-beszel-help pre", text: /compact: true/
    assert_select ".rubylode-beszel-help", text: /welcome text/
    assert_select ".rubylode-beszel-help code", text: /"Servers":\/beszel_status/
    assert_select ".rubylode-beszel-help td", text: /\/issues/
  end

  test "saving placements stores them, and a bad path list is refused with its line" do
    log_user("admin", "admin")
    good = RedmineRubylodeBeszel::Defaults::SETTINGS.merge("hub_url" => "https://beszel.example.com", "show_on_welcome_page" => "1",
                                                           "welcome_page_column" => "left", "show_on_paths" => "/issues\n/projects/*/issues")
    post PATH, params: { settings: good }
    assert_redirected_to PATH
    assert_equal "left", RubylodeBeszel::Configuration.current.welcome_page_column
    assert_equal ["/issues", "/projects/*/issues"], RubylodeBeszel::Configuration.current.path_patterns

    post PATH, params: { settings: good.merge("show_on_paths" => "/ok\nnot-a-path") }
    assert_response :unprocessable_entity
    assert_select "#errorExplanation li", text: /line 2/
    assert_select "textarea[name=?]", "settings[show_on_paths]", text: /not-a-path/
  end

  test "the plugin shows its project address and author on the Plugins page" do
    plugin = Redmine::Plugin.find(:redmine_rubylode_beszel)
    readme = File.read(File.expand_path("../../README.md", __dir__))
    repository_name = readme[%r{git clone https://github\.com/rubylode/([\w-]+)\.git}, 1]
    assert_equal "redmine-rubylode-beszel", repository_name
    assert_equal "https://github.com/rubylode/#{repository_name}", plugin.url
    assert_equal "Rubylode", plugin.author
    assert_equal "https://github.com/rubylode", plugin.author_url
  end
end
