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

# Demo data for trying the server status: the plugin settings pointing at the fake hub in docker-compose.yml, one demo
# person, a project with a wiki page that uses the macro, and the My page block for the administrator and the demo person.
# Everything is made up. Only for the throwaway Redmine in docker-compose.yml.
#
#   ruby bin/demo up        (runs this script)
#   docker compose exec redmine bin/rails runner plugins/redmine_rubylode_beszel/script/seed_demo.rb
#
# Safe to run twice. The demo person signs in as sam.rivera with the password below; the administrator is admin / admin.

DEMO_PASSWORD = "demo-password-1".freeze

Redmine::DefaultData::Loader.load("en") if Tracker.none?
Setting.default_language = "en"
Setting.notified_events = [] # no mail from the demo
Setting.send_mail = nil if Setting.respond_to?(:send_mail=)

admin = User.find_by_login("admin")
admin.update_columns(must_change_passwd: false)
User.current = admin

# The fake hub is reached by its service name over plain http on the compose network, so the box that allows it is ticked.
# The credentials are in the environment of the Redmine container (BESZEL_EMAIL, BESZEL_PASSWORD), never in these settings.
Setting.plugin_redmine_rubylode_beszel = RedmineRubylodeBeszel::Defaults::SETTINGS.merge(
  "hub_url" => "http://fake_beszel:8090",
  "allow_plain_http" => "1",
  "systems" => <<~LIST,
    Web | web-1 | The public site
    Database | db-1 | Primary database
    Backups | backup-1 | Nightly backups
    Worker | worker-1 | Background jobs
  LIST
  "show_on_welcome_page" => "1",
  "show_on_project_overview" => "1",
  "show_on_paths" => "/issues",
  "show_in_top_menu" => "1",
  "cache_seconds" => "5",
  "failure_cache_seconds" => "5"
)

sam = User.find_by_login("sam.rivera") || User.new(login: "sam.rivera", firstname: "Sam", lastname: "Rivera", mail: "sam.rivera@example.com",
                                                   language: "en").tap do |user|
  user.password = DEMO_PASSWORD
  user.password_confirmation = DEMO_PASSWORD
  user.must_change_passwd = false
  user.save!
end

project = Project.find_by(identifier: "operations") || Project.create!(name: "Operations", identifier: "operations", is_public: true,
                                                                       enabled_module_names: %w[wiki issue_tracking])
role = Role.find_by(name: "Developer")
Member.create!(project: project, user: sam, roles: [role]) if role && !project.members.exists?(user_id: sam.id)

project.create_wiki!(start_page: "Wiki") unless project.wiki
wiki = project.wiki
unless wiki.find_page("Servers")
  page = WikiPage.new(wiki: wiki, title: "Servers")
  page.content = WikiContent.new(text: "h1. Servers\n\nWhat the monitoring says right now:\n\n{{beszel_status}}\n", author: admin)
  page.save!
end

[admin, sam].each do |user|
  preference = user.pref
  layout = preference.my_page_layout
  layout["top"] = (layout["top"].to_a | ["rubylode_beszel_status"])
  preference.my_page_layout = layout
  preference.save!
end
puts "demo data loaded"
