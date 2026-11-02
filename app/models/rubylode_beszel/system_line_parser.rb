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
  # Reads the systems textarea: one server per line, "Name | system name in Beszel | Description".
  # Blank lines and lines starting with # are skipped. The description may be empty; an empty Beszel name means
  # "the same as the name". A bad line is reported with its line number and does not stop the others from being read.
  class SystemLineParser
    LineError = Struct.new(:line_number, :message)
    Result = Struct.new(:systems, :errors) do
      def valid?
        errors.empty?
      end
    end

    FIELD_COUNT = 3

    def self.parse(text)
      new(text).parse
    end

    def initialize(text)
      @text = text.to_s
    end

    def parse
      systems = []
      errors = []
      @text.each_line.with_index(1) do |raw_line, line_number|
        line = raw_line.strip
        next if line.empty? || line.start_with?("#")

        system_or_message = read_line(line)
        if system_or_message.is_a?(String)
          errors << LineError.new(line_number, system_or_message)
        else
          systems << system_or_message
        end
      end
      Result.new(systems, errors)
    end

    private

    def read_line(line)
      fields = line.split("|", -1).map(&:strip)
      return I18n.t("rubylode_beszel.errors.line_field_count", count: FIELD_COUNT, found: fields.size) unless fields.size == FIELD_COUNT

      name, beszel_name, description = fields
      return I18n.t("rubylode_beszel.errors.line_name_missing") if name.empty?

      SystemStatus::Server.new(name, beszel_name.empty? ? name : beszel_name, description)
    end
  end
end
