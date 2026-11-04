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
  # only the NAMES of the environment variables that hold them are settings, and a name must start with BESZEL_.
  # Lives in lib because init.rb needs the defaults while the plugin registers.
  class Settings
    PLUGIN_ID = :redmine_rubylode_beszel

    DEFAULTS = {
      "base_url" => "",
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
      "show_on_matching_pages" => "0",
      "matching_page_paths" => "",
      "systems" => "",
      "cache_seconds" => "60",
      "failure_cache_seconds" => "30",
      "timeout_seconds" => "2",
      "block_title" => "Servers",
      "visibility" => "logged_in"
    }.freeze

    VISIBILITIES = %w[logged_in admins].freeze
    COLUMNS = %w[left right].freeze
    # Credentials are only ever read from variables with this prefix, so the settings cannot point the plugin at
    # Redmine's own secrets (SECRET_KEY_BASE, the database password and so on).
    ENVIRONMENT_VARIABLE_PATTERN = /\ABESZEL_[A-Z0-9_]*\z/
    HOST_PATTERN = /\A[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\z/

    def self.current
      new(Setting.send(:"plugin_#{PLUGIN_ID}"))
    end

    def initialize(raw_settings = {})
      @settings = DEFAULTS.merge((raw_settings || {}).to_h.stringify_keys.compact)
    end

    def base_url
      @settings["base_url"].to_s.strip.chomp("/")
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

    def show_on_welcome_page?
      flag?("show_on_welcome_page")
    end

    def welcome_page_column
      column("welcome_page_column")
    end

    # Whether the block is in the default My page, the one people get until they arrange their own.
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

    def show_on_matching_pages?
      flag?("show_on_matching_pages")
    end

    def matching_page_paths_text
      @settings["matching_page_paths"].to_s
    end

    # The path patterns the compact block is drawn on: the typed list when "Pages matching these paths" is checked.
    def matching_page_patterns
      show_on_matching_pages? ? PathMatcher.parse(matching_page_paths_text).patterns : []
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
      title.empty? ? DEFAULTS["block_title"] : title
    end

    def visibility
      VISIBILITIES.include?(@settings["visibility"].to_s) ? @settings["visibility"].to_s : "logged_in"
    end

    def visible_to?(user)
      return false unless user&.logged?

      visibility == "admins" ? user.admin? : true
    end

    def configured?
      !base_url.empty?
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
      return DEFAULTS[key] if name.empty?

      name.match?(ENVIRONMENT_VARIABLE_PATTERN) ? name : nil
    end

    def whole_number(key, minimum:)
      value = Integer(@settings[key].to_s.strip, 10)
      [value, minimum].max
    rescue ArgumentError
      Integer(DEFAULTS[key], 10)
    end
  end
end
