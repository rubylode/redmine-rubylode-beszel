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

class RubylodeBeszel::UsageLevelTest < ActiveSupport::TestCase
  test "below 80 percent is normal, from 80 a warning, from 90 critical" do
    assert_equal :normal, RubylodeBeszel::UsageLevel.for(79.9)
    assert_equal :warning, RubylodeBeszel::UsageLevel.for(80.0)
    assert_equal :warning, RubylodeBeszel::UsageLevel.for(89.9)
    assert_equal :critical, RubylodeBeszel::UsageLevel.for(90.0)
    assert_equal :critical, RubylodeBeszel::UsageLevel.for(100)
  end

  test "no reading has no level" do
    assert_nil RubylodeBeszel::UsageLevel.for(nil)
    assert_nil RubylodeBeszel::UsageLevel.clamp(nil)
  end

  test "a bar width is a whole number kept between 0 and 100" do
    assert_equal 42, RubylodeBeszel::UsageLevel.clamp(41.6)
    assert_equal 100, RubylodeBeszel::UsageLevel.clamp(140.2)
    assert_equal 0, RubylodeBeszel::UsageLevel.clamp(-3)
  end
end
