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

class RubylodeBeszel::WikiMacroTest < Redmine::IntegrationTest
  include RubylodeBeszelTestHelpers

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :issue_statuses, :trackers,
           :projects_trackers, :enumerations, :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  setup do
    use_memory_cache
    configure_plugin
    publish_systems([hub_record("web-1"), hub_record("db-1", status: "down")])
  end

  teardown do
    restore_cache
  end

  def get_wiki_page(text, login: "jsmith")
    page = WikiPage.new(wiki: Project.find(1).wiki, title: "Status_#{SecureRandom.hex(3)}")
    page.content = WikiContent.new(text: text, author: User.find(2))
    page.save!
    log_user(login, login)
    get "/projects/ecookbook/wiki/#{page.title}"
    assert_response :success
  end

  test "the macro draws the status block inside the wiki page" do
    get_wiki_page("Our servers:\n\n{{beszel_status}}")

    assert_select ".wiki .rubylode-beszel-summary", text: "1 of 2 down"
    assert_select ".wiki tr.is-down td.rubylode-beszel-name", text: "Database"
  end

  test "the macro takes a title" do
    get_wiki_page("{{beszel_status(title=Customer-facing)}}")

    assert_select ".wiki h3.rubylode-beszel-title", text: /\ACustomer-facing/
  end

  test "the macro uses the block title setting when it has no title" do
    configure_plugin("block_title" => "Company servers")
    get_wiki_page("{{beszel_status}}")

    assert_select ".wiki h3.rubylode-beszel-title", text: /\ACompany servers/
  end

  test "a person the permission setting excludes sees nothing where the macro stands" do
    configure_plugin("visibility" => "admins")
    get_wiki_page("before {{beszel_status}} after")

    assert_select ".wiki .rubylode-beszel", 0
    assert_select ".wiki", text: /before\s+after/
  end

  test "the macro is listed among the wiki macros" do
    assert Redmine::WikiFormatting::Macros.available_macros.key?(:beszel_status)
  end
end
