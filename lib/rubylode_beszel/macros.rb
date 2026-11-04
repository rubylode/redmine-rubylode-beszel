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
  # Zeitwerk expects this file to define RubylodeBeszel::Macros, so the registration lives in a method that init.rb calls.
  module Macros
    def self.register
      Redmine::WikiFormatting::Macros.register do
        desc <<~DESCRIPTION
          Shows the latest status of the servers monitored by the Beszel hub set in the Rubylode Beszel settings.

            {{beszel_status}}
            {{beszel_status(title=Our servers)}}

          Nothing is shown to people who are not allowed to see it.
        DESCRIPTION
        macro :beszel_status do |_object, arguments|
          _positional, options = extract_macro_options(arguments, :title)
          render partial: "rubylode_beszel/status", locals: { title: options[:title].presence }
        end
      end
    end
  end
end
