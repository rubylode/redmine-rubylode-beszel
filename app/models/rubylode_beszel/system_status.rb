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

module RubylodeBeszel
  # The curated servers joined with what the Beszel hub reports: down first, unknown when the hub has no such system, a
  # summary line, and a "status unavailable" report when the hub cannot be asked. The hub's answer is cached.
  # With no curated list every system the hub has is shown, under the hub's own name.
  class SystemStatus
    Server = Struct.new(:name, :beszel_name, :description)
    SystemState = Struct.new(:name, :description, :state, :last_seen, :cpu_percent, :memory_percent, :disk_percent)
    Report = Struct.new(:systems, :summary, :unavailable, :failure_reason) do
      alias_method :unavailable?, :unavailable

      def any_down?
        systems.any? { |system| system.state == :down }
      end

      def summary_state
        return :unavailable if unavailable?

        any_down? ? :has_down : :all_up
      end
    end

    FAILURE_KEY = "failure".freeze
    STATES = { "up" => :up, "down" => :down, "paused" => :paused }.freeze

    class << self
      attr_writer :cache

      def cache
        @cache ||= Rails.cache
      end

      def cache_key_for(hub_url)
        "rubylode_beszel/systems/#{Digest::SHA256.hexdigest(hub_url.to_s)[0, 16]}"
      end

      # The report for a page. Whatever goes wrong while building it, the page gets a "status unavailable" report and never an error.
      def safe_report(configuration = Configuration.current)
        current(configuration).report
      rescue StandardError => error
        Rails.logger.warn("Rubylode Beszel: could not build the status block: #{error.class}: #{error.message}")
        Report.new([], I18n.t("rubylode_beszel.status.unavailable"), true, error.class.name)
      end

      def current(configuration = Configuration.current)
        new(servers: configuration.systems,
            fetch_systems: -> { BeszelHub.from_configuration(configuration).call },
            cache: cache,
            cache_key: cache_key_for(configuration.hub_url),
            cache_seconds: configuration.cache_seconds,
            failure_seconds: configuration.failure_cache_seconds)
      end
    end

    def initialize(servers:, fetch_systems:, cache:, cache_key: self.class.cache_key_for(""), cache_seconds: 60, failure_seconds: 30)
      @servers = servers
      @fetch_systems = fetch_systems
      @cache = cache
      @cache_key = cache_key
      @cache_seconds = cache_seconds
      @failure_seconds = failure_seconds
    end

    def report
      records = cached_records.index_by { |record| record["name"] }
      servers = @servers.empty? ? records.keys.map { |name| Server.new(name, name, "") } : @servers
      states = servers.map { |server| state_for(server, records[server.beszel_name]) }
      ordered = states.sort_by.with_index { |system, index| [system.state == :down ? 0 : 1, index] }
      Report.new(ordered, summary_for(ordered), false, nil)
    rescue BeszelHub::Unavailable => error
      Report.new([], I18n.t("rubylode_beszel.status.unavailable"), true, error.message)
    end

    private

    def cached_records
      payload = read_cache
      if payload.nil?
        begin
          payload = { "systems" => @fetch_systems.call }
          write_cache(payload, @cache_seconds) if @cache_seconds.positive?
        rescue BeszelHub::Unavailable => error
          payload = { FAILURE_KEY => error.message }
          write_cache(payload, @failure_seconds) if @failure_seconds.positive?
        end
      end
      raise BeszelHub::Unavailable, failure_reason_from(payload) if payload.key?(FAILURE_KEY)

      payload["systems"]
    end

    # A cache that cannot be read or written (a file owned by another user, a full disk) is a miss, not an error.
    def read_cache
      @cache.read(@cache_key)
    rescue StandardError => error
      log_cache_problem("read", error)
      nil
    end

    def write_cache(value, seconds)
      @cache.write(@cache_key, value, expires_in: seconds)
    rescue StandardError => error
      log_cache_problem("write", error)
    end

    def log_cache_problem(action, error)
      Rails.logger.warn("Rubylode Beszel: cache #{action} failed, carrying on without it: #{error.class}: #{error.message}")
    end

    def failure_reason_from(payload)
      reason = payload[FAILURE_KEY].to_s
      reason.empty? ? I18n.t("rubylode_beszel.errors.hub_did_not_answer") : reason
    end

    def state_for(server, record)
      return SystemState.new(server.name, server.description, :unknown, nil, nil, nil, nil) if record.nil?

      SystemState.new(server.name, server.description, STATES.fetch(record["status"], :unknown), parse_time(record["updated"]),
                      record["cpu"], record["memory"], record["disk"])
    end

    def parse_time(text)
      text.to_s.empty? ? nil : Time.zone.parse(text.to_s)
    rescue ArgumentError
      nil
    end

    # Paused and unknown servers are left out of the count: they are neither up nor down.
    def summary_for(systems)
      counted = systems.select { |system| %i[up down].include?(system.state) }
      down = counted.count { |system| system.state == :down }
      return I18n.t("rubylode_beszel.status.all_up") if down.zero?

      I18n.t("rubylode_beszel.status.some_down", down: down, known: counted.size)
    end
  end
end
