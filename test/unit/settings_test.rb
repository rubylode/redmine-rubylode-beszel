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

class RubylodeBeszel::SettingsTest < ActiveSupport::TestCase
  def configuration(settings = {})
    RubylodeBeszel::Settings.new(settings)
  end

  test "a fresh install has the defaults and is not configured" do
    config = configuration

    assert_equal "", config.base_url
    assert_equal "BESZEL_EMAIL", config.email_environment_variable
    assert_equal "BESZEL_PASSWORD", config.password_environment_variable
    assert_equal 60, config.cache_seconds
    assert_equal 30, config.failure_cache_seconds
    assert_equal 2, config.timeout_seconds
    assert_equal "Servers", config.block_title
    assert_equal "logged_in", config.visibility
    refute config.allow_plain_http?
    assert_empty config.allowed_hosts
    refute config.configured?
  end

  test "a hub url makes it configured, with no trailing slash" do
    config = configuration("base_url" => " https://beszel.example.com/ ")

    assert config.configured?
    assert_equal "https://beszel.example.com", config.base_url
  end

  test "numbers are clamped and fall back to the defaults when unreadable" do
    config = configuration("cache_seconds" => "-5", "failure_cache_seconds" => "abc", "timeout_seconds" => "0")

    assert_equal 0, config.cache_seconds
    assert_equal 30, config.failure_cache_seconds
    assert_equal 1, config.timeout_seconds
  end

  test "variable names must start with BESZEL_, otherwise they are not usable at all" do
    config = configuration("email_environment_variable" => "SECRET_KEY_BASE", "password_environment_variable" => "BESZEL_HUB_PASSWORD")

    assert_nil config.email_environment_variable
    assert_equal "BESZEL_HUB_PASSWORD", config.password_environment_variable
  end

  test "lower case and odd characters are not accepted as variable names" do
    assert_nil configuration("email_environment_variable" => "beszel_email").email_environment_variable
    assert_nil configuration("email_environment_variable" => "BESZEL_A B").email_environment_variable
  end

  test "an empty variable name means the default" do
    assert_equal "BESZEL_EMAIL", configuration("email_environment_variable" => " ").email_environment_variable
  end

  test "allowed hosts are split on spaces, commas and lines, and lower-cased" do
    config = configuration("allowed_hosts" => "Hub.Example.com, other.example.com\nthird.example.com")

    assert_equal %w[hub.example.com other.example.com third.example.com], config.allowed_hosts
  end

  test "the plain http box is read" do
    assert configuration("allow_plain_http" => "1").allow_plain_http?
    refute configuration("allow_plain_http" => "0").allow_plain_http?
  end

  test "an empty block title falls back, an unknown visibility becomes logged_in" do
    config = configuration("block_title" => "  ", "visibility" => "everyone")

    assert_equal "Servers", config.block_title
    assert_equal "logged_in", config.visibility
  end

  test "visibility: anonymous never, logged in users by default, admins only when set" do
    admin = User.new.tap { |user| user.admin = true }
    member = User.new
    [admin, member].each { |user| user.define_singleton_method(:logged?) { true } }

    refute configuration.visible_to?(User.anonymous)
    assert configuration.visible_to?(member)
    refute configuration("visibility" => "admins").visible_to?(member)
    assert configuration("visibility" => "admins").visible_to?(admin)
  end
end

class RubylodeBeszel::SettingsPlacementTest < ActiveSupport::TestCase
  def configuration(settings = {})
    RubylodeBeszel::Settings.new(settings)
  end

  test "no placement is on by default" do
    config = configuration

    refute config.show_on_welcome_page?
    refute config.show_on_my_page?
    refute config.show_on_project_overview?
    refute config.show_in_top_menu?
    refute config.show_on_matching_pages?
    assert_empty config.matching_page_patterns
    assert_equal "right", config.welcome_page_column
    assert_equal "right", config.project_overview_column
  end

  test "the boxes and columns are read, an unknown column becomes right" do
    config = configuration("show_on_welcome_page" => "1", "welcome_page_column" => "left", "project_overview_column" => "middle",
                           "show_on_project_overview" => "1", "show_in_top_menu" => "1")

    assert config.show_on_welcome_page?
    assert_equal "left", config.welcome_page_column
    assert_equal "right", config.project_overview_column
    assert config.show_on_project_overview?
    assert config.show_in_top_menu?
  end

  test "the typed paths count only when the matching pages box is checked" do
    paths = "/issues\n/projects/*/issues"

    assert_empty configuration("matching_page_paths" => paths).matching_page_patterns
    assert_equal ["/issues", "/projects/*/issues"], configuration("show_on_matching_pages" => "1", "matching_page_paths" => paths).matching_page_patterns
  end

  test "the My page box does not add a path any more" do
    assert_empty configuration("show_on_my_page" => "1").matching_page_patterns
  end

  test "bad lines in the typed list are left out of the patterns" do
    assert_equal ["/issues"], configuration("show_on_matching_pages" => "1", "matching_page_paths" => "/issues\nnot a path").matching_page_patterns
  end
end
