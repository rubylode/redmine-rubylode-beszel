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
  # "My page" in the settings adds the block to the default My page, the one a person gets until they arrange their own.
  # People who arranged theirs keep their layout and can still add the block from the block list.
  module DefaultMyPagePatch
    BLOCK = "rubylode_beszel_status".freeze

    def default_layout
      layout = super
      layout["top"] = [BLOCK] + layout["top"].to_a if Settings.current.show_on_my_page?
      layout
    end
  end
end
