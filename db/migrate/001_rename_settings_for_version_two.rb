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

# Version 2.0.0 renames two saved settings and adds one: hub_url is base_url, show_on_paths is matching_page_paths, and
# show_on_matching_pages switches the paths on. Writes nothing when no settings were ever saved.
class RenameSettingsForVersionTwo < ActiveRecord::Migration[6.1]
  SETTING_NAME = "plugin_redmine_rubylode_beszel".freeze

  def up
    rewrite_saved_settings do |saved|
      saved["base_url"] = saved.delete("hub_url") if saved.key?("hub_url") && !saved.key?("base_url")
      saved.delete("hub_url")
      if saved.key?("show_on_paths")
        paths = saved.delete("show_on_paths")
        unless saved.key?("matching_page_paths")
          saved["matching_page_paths"] = widen_wildcards(paths)
          saved["show_on_matching_pages"] = paths.to_s.strip.empty? ? "0" : "1"
        end
      end
    end
  end

  def down
    rewrite_saved_settings do |saved|
      saved["hub_url"] = saved.delete("base_url") if saved.key?("base_url")
      if saved.key?("matching_page_paths")
        enabled = saved["show_on_matching_pages"].to_s == "1"
        paths = saved.delete("matching_page_paths")
        saved["show_on_paths"] = enabled ? narrow_wildcards(paths) : ""
      end
      saved.delete("show_on_matching_pages")
    end
  end

  private

  # 1.x let * match slashes; 2.0.0 uses ** for that and * for one segment, so saved patterns keep their meaning.
  def widen_wildcards(paths)
    paths.to_s.gsub("*", "**")
  end

  def narrow_wildcards(paths)
    paths.to_s.gsub("**", "*")
  end

  def rewrite_saved_settings
    return unless Setting.where(name: SETTING_NAME).exists?

    saved = Setting.send(SETTING_NAME).to_h.stringify_keys
    return if saved.empty?

    yield saved
    Setting.send(:"#{SETTING_NAME}=", saved)
  end
end
