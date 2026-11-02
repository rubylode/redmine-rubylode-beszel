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

module RedmineRubylodeBeszel
  PLUGIN_ID = :redmine_rubylode_beszel

  # What a fresh install starts with. Everything here is a plugin setting. The credentials are not: only the NAMES of the two
  # environment variables that hold the sign-in email and password are settings, and a name must start with BESZEL_.
  module Defaults
    SETTINGS = {
      "hub_url" => "",
      "email_environment_variable" => "BESZEL_EMAIL",
      "password_environment_variable" => "BESZEL_PASSWORD",
      "allow_plain_http" => "0",
      "allowed_hosts" => "",
      "show_on_welcome_page" => "0",
      "welcome_page_column" => "right",
      "show_on_my_page" => "0",
      "show_on_project_overview" => "0",
      "project_overview_column" => "right",
      "show_in_top_menu" => "0",
      "show_on_paths" => "",
      "systems" => "",
      "cache_seconds" => "60",
      "failure_cache_seconds" => "30",
      "timeout_seconds" => "2",
      "block_title" => "Servers",
      "visibility" => "logged_in"
    }.freeze
  end
end
