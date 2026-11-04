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
  # The "pages matching these paths" setting: one path pattern per line, "*" matches any run of characters inside one path segment, "**" matches anything (slashes too),
  # blank lines and lines starting with # are skipped. A request path is compared without its query string, fragment and
  # trailing slash.
  #
  # The pages that handle sign-in, accounts and administration never match a pattern that merely reaches them with a
  # wildcard: "/*" or "/a*" leave /admin, /settings and /login alone, and only a pattern that itself starts with one of those
  # prefixes ("/admin/*", "/login") switches the block on there.
  class PathMatcher
    LineError = Struct.new(:line_number, :message)
    Result = Struct.new(:patterns, :errors) do
      def valid?
        errors.empty?
      end
    end

    MAXIMUM_LENGTH = 200
    MAXIMUM_PATTERNS = 50
    PROTECTED_PREFIXES = %w[/admin /settings /login /logout /account /my/account /my/password /users/password].freeze

    def self.parse(text)
      patterns = []
      errors = []
      text.to_s.each_line.with_index(1) do |raw_line, line_number|
        line = raw_line.strip
        next if line.empty? || line.start_with?("#")

        message = problem_with(line)
        message ? errors << LineError.new(line_number, message) : patterns << normalize(line)
      end
      errors << LineError.new(0, I18n.t("rubylode_beszel.errors.path_too_many", maximum: MAXIMUM_PATTERNS)) if patterns.size > MAXIMUM_PATTERNS
      Result.new(patterns, errors)
    end

    def self.problem_with(line)
      return I18n.t("rubylode_beszel.errors.path_too_long", maximum: MAXIMUM_LENGTH) if line.length > MAXIMUM_LENGTH
      return I18n.t("rubylode_beszel.errors.path_must_start_with_slash") unless line.start_with?("/")
      return I18n.t("rubylode_beszel.errors.path_has_host") if line.start_with?("//") || line.include?("://")
      return I18n.t("rubylode_beszel.errors.path_has_query") if line.match?(/[?#]/)
      return I18n.t("rubylode_beszel.errors.path_has_space") if line.match?(/\s/)

      nil
    end

    def self.normalize(path)
      path.length > 1 ? path.chomp("/") : path
    end

    def self.match?(patterns, request_path)
      path = normalize(request_path.to_s.split(/[?#]/).first.to_s)
      protected_prefix = PROTECTED_PREFIXES.find { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      candidates = patterns.map { |pattern| normalize(pattern) }
      candidates = candidates.select { |pattern| pattern.start_with?(protected_prefix) } if protected_prefix
      candidates.any? { |pattern| regexp_for(pattern).match?(path) }
    end

    def self.regexp_for(pattern)
      source = pattern.split(/(\*\*|\*)/, -1).map do |part|
        case part
        when "**" then ".*"
        when "*" then "[^/]*"
        else Regexp.escape(part)
        end
      end.join
      Regexp.new("\\A#{source}\\z")
    end
  end
end
