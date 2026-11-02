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

require File.expand_path("../../../test/test_helper", __dir__)
require "logger"
require "stringio"
require_relative "support/fake_beszel_hub"

module RubylodeBeszelTestHelpers
  PLUGIN_ID = RedmineRubylodeBeszel::PLUGIN_ID

  SAMPLE_SYSTEMS = <<~TEXT.freeze
    Web | web-1 | The public site
    Database | db-1 | Primary database
    Backups | backup-1 |
  TEXT

  # A record the way BeszelHub hands it on: what the hub reported, reduced to the fields the block shows.
  def hub_record(name, status: "up", cpu: 10.0, memory: 20.0, disk: 30.0, updated: "2026-11-01 10:00:00.000Z")
    { "name" => name, "status" => status, "updated" => updated, "cpu" => cpu, "memory" => memory, "disk" => disk }
  end

  def configure_plugin(overrides = {})
    settings = RedmineRubylodeBeszel::Defaults::SETTINGS.merge(
      "hub_url" => "https://beszel.example.com",
      "systems" => SAMPLE_SYSTEMS
    ).merge(overrides.transform_keys(&:to_s))
    Setting.send(:"plugin_#{PLUGIN_ID}=", settings)
  end

  def use_memory_cache
    @original_cache = RubylodeBeszel::SystemStatus.cache
    RubylodeBeszel::SystemStatus.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def restore_cache
    RubylodeBeszel::SystemStatus.cache = @original_cache
  end

  # A cache store that fails the way a cache file owned by another user does.
  class UnwritableCache
    def initialize(read: true, write: true)
      @fail_read = read
      @fail_write = write
    end

    def read(*)
      raise Errno::EACCES, "@ apply2files - /var/cache/entry" if @fail_read
    end

    def write(*)
      raise Errno::EACCES, "@ apply2files - /var/cache/entry" if @fail_write
    end
  end

  # Runs the block with Rails.logger writing into a string, and returns that string.
  def captured_log
    output = StringIO.new
    replacing_method(Rails, :logger, ->(*) { Logger.new(output) }) { yield }
    output.string
  end

  # Minitest 6 ships without stubs, so a singleton method is swapped by hand for the length of the block.
  def replacing_method(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name) { |*arguments, &block| replacement.call(*arguments, &block) }
    yield
  ensure
    target.define_singleton_method(name) { |*arguments, &block| original.call(*arguments, &block) }
  end

  # Puts the hub's answer where the block looks for it, as if the hub had just been asked.
  def publish_systems(records, hub_url: "https://beszel.example.com")
    RubylodeBeszel::SystemStatus.cache.write(RubylodeBeszel::SystemStatus.cache_key_for(hub_url), { "systems" => records })
  end
end
