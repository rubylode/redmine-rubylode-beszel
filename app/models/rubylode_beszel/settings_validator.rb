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
  # Checks the settings form before it is saved. Returns a list of messages, empty when everything is fine.
  # Empty values are fine where the plugin has a default or the setting is optional.
  class SettingsValidator
    NUMBER_FIELDS = { "cache_seconds" => 0, "failure_cache_seconds" => 0, "timeout_seconds" => 1 }.freeze
    VARIABLE_FIELDS = %w[email_environment_variable password_environment_variable].freeze

    def self.errors_for(raw_settings)
      new(raw_settings).errors
    end

    def initialize(raw_settings)
      @settings = (raw_settings || {}).to_h.stringify_keys
    end

    def errors
      messages = []
      messages << t("base_url_invalid") unless blank_or_web_address?("base_url")
      VARIABLE_FIELDS.each { |key| messages << t("environment_variable_invalid", field: I18n.t("rubylode_beszel.settings.#{key}.label")) unless environment_variable_valid?(key) }
      messages << t("plain_http_refused") unless plain_http_allowed?
      messages << t("allowed_hosts_invalid") unless allowed_hosts_valid?
      messages << t("column_invalid") unless columns_valid?
      messages << t("block_title_blank") if @settings.key?("block_title") && @settings["block_title"].to_s.strip.empty?
      messages << t("visibility_invalid") unless visibility_valid?
      messages.concat(number_errors)
      messages.concat(system_errors)
      messages.concat(path_errors)
      messages
    end

    private

    def t(key, **options)
      I18n.t("rubylode_beszel.errors.#{key}", **options)
    end

    def blank_or_web_address?(key)
      value = @settings[key].to_s.strip
      return true if value.empty?

      uri = URI.parse(value)
      %w[http https].include?(uri.scheme) && !uri.host.to_s.empty?
    rescue URI::InvalidURIError
      false
    end

    def environment_variable_valid?(key)
      name = @settings[key].to_s.strip
      name.empty? || name.match?(Settings::ENVIRONMENT_VARIABLE_PATTERN)
    end

    # An http:// hub is only accepted on a loopback host, or when "Allow plain http" is checked.
    def plain_http_allowed?
      url = @settings["base_url"].to_s.strip
      return true unless url.match?(/\Ahttp:/i)

      @settings["allow_plain_http"].to_s == "1" || SecureTransport.loopback_host?(URI.parse(url).host)
    rescue URI::InvalidURIError
      true
    end

    def allowed_hosts_valid?
      Settings.new("allowed_hosts" => @settings["allowed_hosts"]).allowed_hosts.all? { |host| host.match?(Settings::HOST_PATTERN) }
    end

    def columns_valid?
      %w[welcome_page_column project_overview_column].all? { |key| !@settings.key?(key) || Settings::COLUMNS.include?(@settings[key].to_s) }
    end

    def path_errors
      PathMatcher.parse(@settings["matching_page_paths"]).errors.map do |line_error|
        line_error.line_number.zero? ? line_error.message : t("path_line_prefix", line_number: line_error.line_number, message: line_error.message)
      end
    end

    def visibility_valid?
      !@settings.key?("visibility") || Settings::VISIBILITIES.include?(@settings["visibility"].to_s)
    end

    def number_errors
      NUMBER_FIELDS.filter_map do |key, minimum|
        value = @settings[key].to_s.strip
        next if value.empty?

        valid = value.match?(/\A\d+\z/) && value.to_i >= minimum
        t("number_invalid", field: I18n.t("rubylode_beszel.settings.#{key}.label"), minimum: minimum) unless valid
      end
    end

    def system_errors
      SystemLineParser.parse(@settings["systems"]).errors.map do |line_error|
        t("line_prefix", line_number: line_error.line_number, message: line_error.message)
      end
    end
  end
end
