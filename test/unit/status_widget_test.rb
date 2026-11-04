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

class RubylodeBeszel::StatusWidgetTest < ActiveSupport::TestCase
  include RubylodeBeszelTestHelpers

  setup do
    use_memory_cache
    configure_plugin
  end

  teardown do
    restore_cache
  end

  def widget_data(records)
    publish_systems(records)
    RubylodeBeszel::StatusWidget.data
  end

  test "all servers up is ok, with a one-line summary and one item per server" do
    data = widget_data([hub_record("web-1"), hub_record("db-1"), hub_record("backup-1")])

    assert_equal "ok", data[:state]
    assert_equal "3 of 3 servers up", data[:summary]
    assert_equal [{ name: "Web", state: "ok", detail: nil }, { name: "Database", state: "ok", detail: nil },
                  { name: "Backups", state: "ok", detail: nil }], data[:items]
  end

  test "one server down among three is a warning, and the down server comes first" do
    data = widget_data([hub_record("web-1"), hub_record("db-1", status: "down"), hub_record("backup-1")])

    assert_equal "warning", data[:state]
    assert_equal "2 of 3 servers up", data[:summary]
    assert_equal({ name: "Database", state: "down", detail: nil }, data[:items].first)
  end

  test "every counted server down is down" do
    data = widget_data([hub_record("web-1", status: "down"), hub_record("db-1", status: "down"), hub_record("backup-1", status: "down")])

    assert_equal "down", data[:state]
    assert_equal "0 of 3 servers up", data[:summary]
  end

  test "an up server with a high reading is a warning item that names the reading, and the block is a warning" do
    data = widget_data([hub_record("web-1", cpu: 91.4, disk: 40.0), hub_record("db-1"), hub_record("backup-1")])

    assert_equal "warning", data[:state]
    assert_equal({ name: "Web", state: "warning", detail: "CPU 91%" }, data[:items].find { |item| item[:name] == "Web" })
    assert_equal "3 of 3 servers up", data[:summary]
  end

  test "paused and unknown servers are unknown items and are not counted" do
    data = widget_data([hub_record("web-1", status: "paused"), hub_record("db-1")])

    assert_equal "ok", data[:state]
    assert_equal "1 of 1 server up", data[:summary]
    assert_equal({ name: "Web", state: "unknown", detail: "Paused" }, data[:items].find { |item| item[:name] == "Web" })
    assert_equal({ name: "Backups", state: "unknown", detail: nil }, data[:items].find { |item| item[:name] == "Backups" })
  end

  test "only paused or unknown servers leave the block unknown" do
    data = widget_data([hub_record("web-1", status: "paused")])

    assert_equal "unknown", data[:state]
  end

  test "when the hub cannot be asked the block is unknown with no items" do
    RubylodeBeszel::SystemStatus.cache.write(RubylodeBeszel::SystemStatus.cache_key_for("https://beszel.example.com"), { "failure" => "The Beszel hub answered 503" })
    data = RubylodeBeszel::StatusWidget.data

    assert_equal "unknown", data[:state]
    assert_equal "Status unavailable", data[:summary]
    assert_empty data[:items]
  end

  test "without a Beszel address the block is unknown and says it is not set up" do
    configure_plugin("base_url" => "")
    data = RubylodeBeszel::StatusWidget.data

    assert_equal "unknown", data[:state]
    assert_equal "Not set up yet", data[:summary]
    assert_empty data[:items]
  end

  test "registering with the Status plugin passes the key, the page path and the settings" do
    configure_plugin("block_title" => "Our servers", "visibility" => "admins")
    with_fake_status_registry do |registry|
      assert RubylodeBeszel::StatusWidget.register_with_status_plugin

      call = registry.calls.fetch(0)
      assert_equal "beszel", call[:key]
      assert_equal "/status/beszel", call[:path]
      assert_equal "rubylode_beszel/status", call[:partial]
      assert_equal "Our servers", call[:title].call
      assert_equal "admins", call[:visibility].call
      assert_equal RubylodeBeszel::StatusWidget.data, call[:data].call
    end
  end

  test "registration is skipped when the Status plugin is not there" do
    refute defined?(RubylodeStatus::Registry)
    refute RubylodeBeszel::StatusWidget.register_with_status_plugin
  end

  test "the Status plugin counts as present exactly when its registry is defined" do
    refute RubylodeBeszel::StatusWidget.status_plugin_present?
    with_fake_status_registry { assert RubylodeBeszel::StatusWidget.status_plugin_present? }
    refute RubylodeBeszel::StatusWidget.status_plugin_present?
  end
end
