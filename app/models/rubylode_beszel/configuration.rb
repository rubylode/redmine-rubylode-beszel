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

module RubylodeBeszel
  # The plugin's settings, read with their defaults and clamped to sensible values. The credentials are not among them:
  # only the NAMES of the environment variables that hold them are settings.
  class Configuration
    VISIBILITIES = %w[logged_in admins].freeze
    # Credentials are only ever read from variables with this prefix, so the settings cannot point the plugin at
    # Redmine's own secrets (SECRET_KEY_BASE, the database password and so on).
    ENVIRONMENT_VARIABLE_PATTERN = /\ABESZEL_[A-Z0-9_]*\z/
    HOST_PATTERN = /\A[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\z/

    def self.current
      new(Setting.send(:"plugin_#{RedmineRubylodeBeszel::PLUGIN_ID}"))
    end

    def initialize(raw_settings = {})
      @settings = RedmineRubylodeBeszel::Defaults::SETTINGS.merge((raw_settings || {}).to_h.stringify_keys.compact)
    end

    def hub_url
      @settings["hub_url"].to_s.strip.chomp("/")
    end

    # The saved name when it is allowed, the default when the setting is empty, nil when it is not allowed: nil means
# "treat the credential as missing", and nothing is read from the environment.
    def email_environment_variable
      variable_name("email_environment_variable")
    end

    def password_environment_variable
      variable_name("password_environment_variable")
    end

    # Other hosts a redirect from the hub may lead to, with credentials. The hub's own host is always allowed.
    def allowed_hosts
      @settings["allowed_hosts"].to_s.split(/[\s,]+/).reject(&:empty?).map(&:downcase).uniq
    end

    def allow_plain_http?
      @settings["allow_plain_http"].to_s == "1"
    end

    COLUMNS = %w[left right].freeze
    MY_PAGE_PATH = "/my/page".freeze

    def show_on_welcome_page?
      flag?("show_on_welcome_page")
    end

    def welcome_page_column
      column("welcome_page_column")
    end

    def show_on_my_page?
      flag?("show_on_my_page")
    end

    def show_on_project_overview?
      flag?("show_on_project_overview")
    end

    def project_overview_column
      column("project_overview_column")
    end

    def show_in_top_menu?
      flag?("show_in_top_menu")
    end

    def show_on_paths_text
      @settings["show_on_paths"].to_s
    end

    # The path patterns the compact block is drawn on: the My page, when ticked, plus the typed list.
    def path_patterns
      listed = PathMatcher.parse(show_on_paths_text).patterns
      show_on_my_page? ? [MY_PAGE_PATH] + listed : listed
    end

    def systems_text
      @settings["systems"].to_s
    end

    # The curated list; empty when the settings list nothing, which means "show every system the hub has".
    def systems
      SystemLineParser.parse(systems_text).systems
    end

    def cache_seconds
      whole_number("cache_seconds", minimum: 0)
    end

    def failure_cache_seconds
      whole_number("failure_cache_seconds", minimum: 0)
    end

    def timeout_seconds
      whole_number("timeout_seconds", minimum: 1)
    end

    def block_title
      title = @settings["block_title"].to_s.strip
      title.empty? ? RedmineRubylodeBeszel::Defaults::SETTINGS["block_title"] : title
    end

    def visibility
      VISIBILITIES.include?(@settings["visibility"].to_s) ? @settings["visibility"].to_s : "logged_in"
    end

    def visible_to?(user)
      return false unless user&.logged?

      visibility == "admins" ? user.admin? : true
    end

    def configured?
      !hub_url.empty?
    end

    private

    def flag?(key)
      @settings[key].to_s == "1"
    end

    def column(key)
      COLUMNS.include?(@settings[key].to_s) ? @settings[key].to_s : "right"
    end

    def variable_name(key)
      name = @settings[key].to_s.strip
      return RedmineRubylodeBeszel::Defaults::SETTINGS[key] if name.empty?

  name.match?(ENVIRONMENT_VARIABLE_PATTERN) ? name : nil
    end

    def whole_number(key, minimum:)
      value = Integer(@settings[key].to_s.strip, 10)
      [value, minimum].max
    rescue ArgumentError
      Integer(RedmineRubylodeBeszel::Defaults::SETTINGS[key], 10)
    end
  end
end
