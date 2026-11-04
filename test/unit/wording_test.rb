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

# What people read: no em or en dashes, en-US spelling, and the one name for the block.
class RubylodeBeszel::WordingTest < ActiveSupport::TestCase
  ROOT = File.expand_path("../..", __dir__)
  READ_BY_PEOPLE = %w[config/locales/en.yml README.md CHANGELOG.md init.rb docs/redmine-org-listing.md docs/roadmap/ROADMAP.md].freeze

  def files_people_read
    READ_BY_PEOPLE + Dir.glob("app/**/*.{erb,rb}", base: ROOT) + Dir.glob("lib/**/*.rb", base: ROOT)
  end

  test "nothing people read has an em or an en dash" do
    offenders = files_people_read.select { |path| File.read(File.join(ROOT, path)).match?(/[–—]/) }

    assert_empty offenders
  end

  test "spelling is en-US" do
    offenders = files_people_read.select { |path| File.read(File.join(ROOT, path)).match?(/\b(licence|colour|behaviour|organis\w+)\b/i) }

    assert_empty offenders
  end

  test "Server status is not a name for the block (the changelog may name the old one)" do
    offenders = (files_people_read - ["CHANGELOG.md"]).select { |path| File.read(File.join(ROOT, path)).include?("Server status") }

    assert_empty offenders
  end

  test "the locale has one root and only the keys Redmine reads sit outside it" do
    locale = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en")

    assert_equal %w[my rubylode_beszel], locale.keys.sort
    assert_equal %w[rubylode_beszel_status], locale.dig("my", "blocks").keys
  end

  test "the block title default is Servers" do
    assert_equal "Servers", RubylodeBeszel::Settings.new.block_title
    assert_equal "Servers", I18n.t("my.blocks.rubylode_beszel_status")
  end
end
