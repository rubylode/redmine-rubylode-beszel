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

class RubylodeBeszel::SystemLineParserTest < ActiveSupport::TestCase
  def parse(text)
    RubylodeBeszel::SystemLineParser.parse(text)
  end

  test "reads name, Beszel name and description" do
    result = parse("Web | web-1 | The public site")

    assert result.valid?
    server = result.systems.first
    assert_equal ["Web", "web-1", "The public site"], [server.name, server.beszel_name, server.description]
  end

  test "an empty Beszel name means the same as the name, and the description may be empty" do
    server = parse("db-1 | |").systems.first

    assert_equal "db-1", server.beszel_name
    assert_equal "", server.description
  end

  test "blank lines and comments are skipped" do
    result = parse("# the servers\n\nWeb | web-1 | Site\n   \n")

    assert_equal 1, result.systems.size
    assert result.valid?
  end

  test "a bad line is reported with its number and the others are still read" do
    result = parse("Web | web-1 | Site\nbroken\n | x | y\nDb | db-1 | d")

    assert_equal %w[Web Db], result.systems.map(&:name)
    assert_equal [2, 3], result.errors.map(&:line_number)
    refute result.valid?
  end

  test "too many fields is an error" do
    assert_match(/needs 3 fields/, parse("a | b | c | d").errors.first.message)
  end

  test "nothing at all gives an empty list" do
    assert_empty parse(nil).systems
    assert_empty parse("").systems
  end
end
