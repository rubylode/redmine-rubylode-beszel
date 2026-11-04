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

class RubylodeBeszel::SystemStatusTest < ActiveSupport::TestCase
  include RubylodeBeszelTestHelpers

  SERVERS = [
    RubylodeBeszel::SystemStatus::Server.new("Web", "web-1", "Public site"),
    RubylodeBeszel::SystemStatus::Server.new("Database", "db-1", "Primary"),
    RubylodeBeszel::SystemStatus::Server.new("Backups", "backup-1", "")
  ].freeze

  def report_for(records, servers: SERVERS)
    RubylodeBeszel::SystemStatus.new(servers: servers, fetch_systems: -> { records }, cache: ActiveSupport::Cache::MemoryStore.new).report
  end

  test "every curated system up shows each up and the all-up summary" do
    report = report_for([hub_record("web-1"), hub_record("db-1"), hub_record("backup-1")])

    assert_equal %w[Web Database Backups], report.systems.map(&:name)
    assert_equal [:up], report.systems.map(&:state).uniq
    assert_equal "All servers up", report.summary
    assert_equal :all_up, report.summary_state
  end

  test "down systems come first and the summary counts them" do
    report = report_for([hub_record("web-1"), hub_record("db-1", status: "down"), hub_record("backup-1")])

    assert_equal %w[Database Web Backups], report.systems.map(&:name)
    assert_equal "1 of 3 down", report.summary
    assert_equal :has_down, report.summary_state
  end

  test "systems the hub does not know are unknown and not counted" do
    report = report_for([hub_record("web-1"), hub_record("db-1", status: "down")])

    assert_equal :unknown, report.systems.last.state
    assert_equal "1 of 2 down", report.summary
  end

  test "paused and pending systems are not counted as up or down" do
    report = report_for([hub_record("web-1", status: "paused"), hub_record("db-1", status: "pending"), hub_record("backup-1")])

    assert_equal [:paused, :unknown, :up], report.systems.map(&:state)
    assert_equal "All servers up", report.summary
  end

  test "systems the hub has but the list leaves out do not appear" do
    report = report_for([hub_record("web-1"), hub_record("staging-1", status: "down")])

    refute_includes report.systems.map(&:name), "staging-1"
    assert_equal "All servers up", report.summary
  end

  test "with no curated list every system of the hub is shown under its own name" do
    report = report_for([hub_record("web-1"), hub_record("db-1", status: "down")], servers: [])

    assert_equal %w[db-1 web-1], report.systems.map(&:name)
    assert_equal "1 of 2 down", report.summary
  end

  test "readings and the last seen time come through" do
    report = report_for([hub_record("web-1", cpu: 12.5, memory: 40.0, disk: 91.0, updated: "2026-11-01 10:00:00.000Z")])
    web = report.systems.find { |system| system.name == "Web" }

    assert_equal [12.5, 40.0, 91.0], [web.cpu_percent, web.memory_percent, web.disk_percent]
    assert_equal Time.utc(2026, 11, 1, 10, 0, 0), web.last_seen
  end

  test "an unreadable updated time is no last seen time" do
    web = report_for([hub_record("web-1", updated: "garbage")]).systems.first

    assert_nil web.last_seen
  end

  test "when the hub cannot be asked the report says status unavailable with the reason" do
    unavailable = RubylodeBeszel::SystemStatus.new(servers: SERVERS, cache: ActiveSupport::Cache::MemoryStore.new,
                                                   fetch_systems: -> { raise RubylodeBeszel::BeszelHub::Unavailable, "The Beszel hub answered 503" })
    report = unavailable.report

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal "The Beszel hub answered 503", report.failure_reason
    assert_empty report.systems
    assert_equal :unavailable, report.summary_state
  end

  test "the hub is asked once within the cache window" do
    calls = 0
    status = RubylodeBeszel::SystemStatus.new(servers: SERVERS, cache: ActiveSupport::Cache::MemoryStore.new,
                                              fetch_systems: -> { calls += 1; [hub_record("web-1")] }, cache_seconds: 60)
    2.times { status.report }

    assert_equal 1, calls
  end

  test "a failure is remembered for the failure window, so a broken hub is not hammered" do
    calls = 0
    status = RubylodeBeszel::SystemStatus.new(servers: SERVERS, cache: ActiveSupport::Cache::MemoryStore.new, failure_seconds: 30,
                                              fetch_systems: -> { calls += 1; raise RubylodeBeszel::BeszelHub::Unavailable, "down" })
    2.times { status.report }

    assert_equal 1, calls
  end

  test "with a cache of zero seconds every call asks the hub" do
    calls = 0
    status = RubylodeBeszel::SystemStatus.new(servers: SERVERS, cache: ActiveSupport::Cache::MemoryStore.new, cache_seconds: 0,
                                              fetch_systems: -> { calls += 1; [hub_record("web-1")] })
    2.times { status.report }

    assert_equal 2, calls
  end

  def status_with_cache(cache, &fetch)
    RubylodeBeszel::SystemStatus.new(servers: SERVERS, fetch_systems: fetch, cache: cache)
  end

  test "a cache that cannot be read or written still gives the report from a live fetch, and logs a warning" do
    calls = 0
    report = nil
    log = captured_log do
      report = status_with_cache(UnwritableCache.new) { calls += 1; [hub_record("web-1"), hub_record("db-1"), hub_record("backup-1")] }.report
    end

    refute report.unavailable?
    assert_equal "All servers up", report.summary
    assert_equal 1, calls
    assert_includes log, "WARN"
    assert_includes log, "Errno::EACCES"
  end

  test "a cache that cannot be written still gives the report from a live fetch" do
    report = nil
    log = captured_log { report = status_with_cache(UnwritableCache.new(read: false)) { [hub_record("web-1"), hub_record("db-1", status: "down")] }.report }

    refute report.unavailable?
    assert_equal "1 of 2 down", report.summary
    assert_includes log, "cache write failed"
  end

  test "a failed fetch with a cache that cannot be written is the status unavailable report" do
    report = nil
    captured_log do
      report = status_with_cache(UnwritableCache.new) { raise RubylodeBeszel::BeszelHub::Unavailable, "The Beszel hub answered 503" }.report
    end

    assert report.unavailable?
    assert_equal "The Beszel hub answered 503", report.failure_reason
  end

  test "any error from the cache store is ignored, not only system call errors" do
    cache = Object.new
    def cache.read(*) = raise(TypeError, "incompatible marshal file format")
    def cache.write(*) = raise(IOError, "closed stream")
    report = nil
    captured_log { report = status_with_cache(cache) { [hub_record("web-1")] }.report }

    refute report.unavailable?
  end

  test "safe_report answers status unavailable and logs the class when building the report raises" do
    configuration = RubylodeBeszel::Settings.current
    report = nil
    log = captured_log do
      replacing_method(RubylodeBeszel::SystemStatus, :current, ->(*) { raise ArgumentError, "boom" }) do
        report = RubylodeBeszel::SystemStatus.safe_report(configuration)
      end
    end

    assert report.unavailable?
    assert_equal "Status unavailable", report.summary
    assert_equal "ArgumentError", report.failure_reason
    assert_includes log, "ArgumentError: boom"
  end
end
