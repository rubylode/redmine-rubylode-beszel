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

class RubylodeBeszel::SettingsValidatorTest < ActiveSupport::TestCase
  def errors_for(settings)
    RubylodeBeszel::SettingsValidator.errors_for(settings)
  end

  test "good settings have no errors" do
    assert_empty errors_for("hub_url" => "https://beszel.example.com", "email_environment_variable" => "BESZEL_EMAIL",
                            "systems" => "Web | web-1 | Site", "cache_seconds" => "60", "visibility" => "admins", "block_title" => "Servers")
  end

  test "empty settings are fine, the defaults apply" do
    assert_empty errors_for({})
  end

  test "the hub url must be a web address" do
    assert_equal 1, errors_for("hub_url" => "ftp://nope").size
    assert_equal 1, errors_for("hub_url" => "not a url").size
  end

  test "variable names outside the BESZEL_ prefix are rejected, Redmine's own secrets included" do
    %w[SECRET_KEY_BASE DATABASE_PASSWORD PATH beszel_email].each do |name|
      assert_equal 1, errors_for("email_environment_variable" => name).size, name
      assert_equal 1, errors_for("password_environment_variable" => name).size, name
    end
    assert_match(/BESZEL_/, errors_for("email_environment_variable" => "SECRET_KEY_BASE").first)
  end

  test "an http hub url needs the plain http box unless the host is loopback" do
    assert_equal 1, errors_for("hub_url" => "http://beszel.example.com").size
    assert_empty errors_for("hub_url" => "http://beszel.example.com", "allow_plain_http" => "1")
    assert_empty errors_for("hub_url" => "http://localhost:8090")
    assert_empty errors_for("hub_url" => "http://127.0.0.1:8090")
  end

  test "allowed hosts must be host names" do
    assert_empty errors_for("allowed_hosts" => "a.example.com, b.example.com")
    assert_equal 1, errors_for("allowed_hosts" => "https://a.example.com/path").size
  end

  test "numbers must be whole and not below their minimum" do
    assert_equal 3, errors_for("cache_seconds" => "x", "failure_cache_seconds" => "-1", "timeout_seconds" => "0").size
  end

  test "an empty block title and an unknown visibility are errors" do
    assert_equal 2, errors_for("block_title" => " ", "visibility" => "all").size
  end

  test "each bad server line is reported with its line number" do
    messages = errors_for("systems" => "Web | web-1 | Site\nbroken\nalso broken")

    assert_equal 2, messages.size
    assert_match(/line 2/, messages.first)
    assert_match(/line 3/, messages.last)
  end
end

class RubylodeBeszel::SettingsValidatorPlacementTest < ActiveSupport::TestCase
  def errors_for(settings)
    RubylodeBeszel::SettingsValidator.errors_for(settings)
  end

  test "good paths and columns have no errors" do
    assert_empty errors_for("show_on_paths" => "/issues\n/projects/*/issues", "welcome_page_column" => "left", "project_overview_column" => "right")
  end

  test "a path without a leading slash, with a host or with a query is refused, each with its line" do
    messages = errors_for("show_on_paths" => "issues\nhttps://example.com/x\n/a?b=1")

    assert_equal 3, messages.size
    assert_match(/line 1.*must start with \//, messages[0])
    assert_match(/line 2/, messages[1])
    assert_match(/line 3/, messages[2])
  end

  test "an overlong path is refused" do
    assert_equal 1, errors_for("show_on_paths" => "/#{'x' * 250}").size
  end

  test "a column other than left or right is refused" do
    assert_equal 1, errors_for("welcome_page_column" => "top").size
    assert_equal 1, errors_for("project_overview_column" => "").size
  end
end
