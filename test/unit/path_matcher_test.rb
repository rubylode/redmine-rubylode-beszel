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

class RubylodeBeszel::PathMatcherTest < ActiveSupport::TestCase
  def match?(patterns, path)
    RubylodeBeszel::PathMatcher.match?(Array(patterns), path)
  end

  test "an exact path matches itself and nothing longer" do
    assert match?("/issues", "/issues")
    refute match?("/issues", "/issues/1")
    refute match?("/issues", "/projects/a/issues")
  end

  test "a star matches any run of characters" do
    assert match?("/projects/*/issues", "/projects/ecookbook/issues")
    assert match?("/projects/*/issues", "/projects/a/b/issues")
    refute match?("/projects/*/issues", "/projects/ecookbook/wiki")
    assert match?("/issues/*", "/issues/1")
    assert match?("/wiki*", "/wiki")
  end

  test "regular expression characters in a pattern are literal" do
    assert match?("/a.b", "/a.b")
    refute match?("/a.b", "/axb")
    refute match?("/a+", "/aaa")
  end

  test "the query string and the fragment of the request are ignored" do
    assert match?("/issues", "/issues?set_filter=1&status_id=o")
    assert match?("/issues", "/issues#top")
  end

  test "a trailing slash does not matter on either side" do
    assert match?("/issues", "/issues/")
    assert match?("/issues/", "/issues")
  end

  test "the root path matches only the root" do
    assert match?("/", "/")
    refute match?("/", "/issues")
  end

  test "several patterns: any of them may match" do
    assert match?(["/issues", "/news"], "/news")
    refute match?(["/issues", "/news"], "/wiki")
    refute match?([], "/issues")
  end

  test "a wildcard never reaches the administration, settings or sign-in pages" do
    %w[/admin /admin/projects /settings /settings/plugin/redmine_rubylode_beszel /login /logout /account/register /my/account /my/password].each do |path|
      refute match?("/*", path), "/* matched #{path}"
      refute match?("/a*", path) if path.start_with?("/a")
    end
    refute match?("*", "/admin")
  end

  test "a pattern that starts with a protected prefix does reach it" do
    assert match?("/login", "/login")
    assert match?("/admin/*", "/admin/projects")
    assert match?("/settings*", "/settings/plugin/x")
    refute match?("/admin/*", "/admin")
    refute match?("/login", "/logout")
  end

  test "a protected path is not matched by a pattern for another protected path" do
    refute match?("/login", "/admin")
  end

  test "parse keeps good patterns, skips blank lines and comments, and strips trailing slashes" do
    result = RubylodeBeszel::PathMatcher.parse("# issues\n/issues\n\n  /projects/*/issues/  \n")

    assert result.valid?
    assert_equal ["/issues", "/projects/*/issues"], result.patterns
  end

  test "parse reports each bad line with its number" do
    result = RubylodeBeszel::PathMatcher.parse("/ok\nissues\nhttps://example.com/issues\n//evil.example.com/x\n/a?b=1\n/a b\n/#{'x' * 300}")

    assert_equal ["/ok"], result.patterns
    assert_equal [2, 3, 4, 5, 6, 7], result.errors.map(&:line_number)
    refute result.valid?
  end

  test "too many patterns are an error" do
    result = RubylodeBeszel::PathMatcher.parse((1..51).map { |number| "/p#{number}" }.join("\n"))

    refute result.valid?
  end

  test "nothing at all is fine" do
    assert RubylodeBeszel::PathMatcher.parse(nil).valid?
    assert_empty RubylodeBeszel::PathMatcher.parse("").patterns
  end
end
