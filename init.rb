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

require "redmine"
require_relative "lib/rubylode_beszel/settings"

Redmine::Plugin.register :redmine_rubylode_beszel do
  name "Rubylode Beszel"
  author "Rubylode"
  author_url "https://github.com/rubylode"
  url "https://github.com/rubylode/redmine-rubylode-beszel"
  description "The latest status of the servers monitored by a Beszel hub: a wiki macro, a page, a My page block and a partial"
  version "2.1.0"
  requires_redmine version_or_higher: "5.1.0"

  # A link to the page in the top menu, shown only when the settings ask for it and only to the people allowed to see the block.
  # With Rubylode Status installed the block lives on its page, so this item goes.
  menu :top_menu, :rubylode_beszel_status, { controller: "rubylode_beszel_status", action: "show" },
       caption: proc { RubylodeBeszel::Settings.current.block_title },
       if: proc {
         settings = RubylodeBeszel::Settings.current
         !RubylodeBeszel::StatusWidget.status_plugin_present? && settings.show_in_top_menu? && settings.visible_to?(User.current)
       }

  settings default: RubylodeBeszel::Settings::DEFAULTS, partial: "settings/rubylode_beszel"
end

require_relative "lib/rubylode_beszel/macros"
RubylodeBeszel::Macros.register
require_relative "lib/rubylode_beszel/hooks"
require_relative "lib/rubylode_beszel/settings_controller_patch"
require_relative "lib/rubylode_beszel/default_my_page_patch"
Redmine::MyPage.singleton_class.prepend(RubylodeBeszel::DefaultMyPagePatch)

# Plugins load after the boot-time prepare callbacks have run, so apply the patch now and again after each code reload.
apply_settings_controller_patch = lambda do
  unless SettingsController.include?(RubylodeBeszel::SettingsControllerPatch)
    SettingsController.prepend RubylodeBeszel::SettingsControllerPatch
  end
end
apply_settings_controller_patch.call
Rails.configuration.to_prepare(&apply_settings_controller_patch)

# Puts the block on the Status page when Rubylode Status is installed. See its docs/widget-contract.md.
# Redmine loads plugins in alphabetical order, so this plugin's init.rb runs before the Status plugin's: wait for all of them.
Rails.application.config.after_initialize do
  RubylodeBeszel::StatusWidget.register_with_status_plugin
end
