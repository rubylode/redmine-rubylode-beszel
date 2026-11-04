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

require_relative "../test_helper"
require File.expand_path("../../db/migrate/001_rename_beszel_settings_for_version_two", __dir__)

class RubylodeBeszel::RenameSettingsMigrationTest < ActiveSupport::TestCase
  SETTING_NAME = "plugin_redmine_rubylode_beszel".freeze

  setup do
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  teardown do
    Setting.where(name: SETTING_NAME).delete_all
    Setting.clear_cache
  end

  def save(settings)
    Setting.send(:"#{SETTING_NAME}=", settings)
  end

  def saved
    Setting.clear_cache
    Setting.send(SETTING_NAME)
  end

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { RenameBeszelSettingsForVersionTwo.new.migrate(direction) }
  end

  test "up renames hub_url and show_on_paths, switches the paths on and keeps the rest" do
    save("hub_url" => "https://beszel.example.com", "show_on_paths" => "/issues", "block_title" => "Our servers", "show_on_my_page" => "1")
    migrate(:up)

    assert_equal "https://beszel.example.com", saved["base_url"]
    assert_equal "/issues", saved["matching_page_paths"]
    assert_equal "1", saved["show_on_matching_pages"]
    assert_equal "Our servers", saved["block_title"]
    assert_equal "1", saved["show_on_my_page"]
    refute saved.key?("hub_url")
    refute saved.key?("show_on_paths")
  end

  test "up turns every * into ** so saved patterns keep their meaning" do
    save("show_on_paths" => "/projects/*/issues\n/wiki*")
    migrate(:up)

    assert_equal "/projects/**/issues\n/wiki**", saved["matching_page_paths"]
  end

  test "down turns ** back into *" do
    save("matching_page_paths" => "/projects/**/issues\n/wiki**", "show_on_matching_pages" => "1")
    migrate(:down)

    assert_equal "/projects/*/issues\n/wiki*", saved["show_on_paths"]
  end

  test "up leaves the paths switched off when there were none" do
    save("hub_url" => "https://beszel.example.com", "show_on_paths" => " \n")
    migrate(:up)

    assert_equal "0", saved["show_on_matching_pages"]
  end

  test "up does not overwrite a value that is already under the new key" do
    save("hub_url" => "https://old.example.com", "base_url" => "https://new.example.com")
    migrate(:up)

    assert_equal "https://new.example.com", saved["base_url"]
    refute saved.key?("hub_url")
  end

  test "up writes nothing when no settings were saved" do
    migrate(:up)

    refute Setting.where(name: SETTING_NAME).exists?
  end

  test "down moves the settings back to the old keys" do
    save("base_url" => "https://beszel.example.com", "matching_page_paths" => "/issues", "show_on_matching_pages" => "1", "block_title" => "Servers")
    migrate(:down)

    assert_equal "https://beszel.example.com", saved["hub_url"]
    assert_equal "/issues", saved["show_on_paths"]
    assert_equal "Servers", saved["block_title"]
    %w[base_url matching_page_paths show_on_matching_pages].each { |key| refute saved.key?(key), key }
  end

  test "down drops the paths when the matching pages box was off, since 1.x had no such box" do
    save("base_url" => "https://beszel.example.com", "matching_page_paths" => "/issues", "show_on_matching_pages" => "0")
    migrate(:down)

    assert_equal "", saved["show_on_paths"]
  end

  test "down writes nothing when no settings were saved" do
    migrate(:down)

    refute Setting.where(name: SETTING_NAME).exists?
  end
end
