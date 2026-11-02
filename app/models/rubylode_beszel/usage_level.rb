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
  # How worried a usage bar should look: normal, warning from 80 percent, critical from 90 percent, nothing for no reading.
  module UsageLevel
    WARNING_PERCENT = 80.0
    CRITICAL_PERCENT = 90.0

    def self.for(percent)
      return nil if percent.nil?
      return :critical if percent >= CRITICAL_PERCENT
      return :warning if percent >= WARNING_PERCENT

      :normal
    end

    # A whole number from 0 to 100, for a bar's width and its label.
    def self.clamp(percent)
      percent.nil? ? nil : percent.round.clamp(0, 100)
    end
  end
end
