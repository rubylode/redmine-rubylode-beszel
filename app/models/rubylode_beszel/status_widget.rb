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
  # What the Beszel block hands to Rubylode Status: a state (ok, warning, down or unknown), a one-line summary and one item
  # per server. See the Status plugin's docs/widget-contract.md. Works without the Status plugin; then nothing is registered.
  module StatusWidget
    KEY = "beszel".freeze
    PAGE_PATH = "/status/beszel".freeze
    PARTIAL = "rubylode_beszel/status".freeze
    ITEM_STATES = { up: "ok", down: "down", paused: "unknown", unknown: "unknown" }.freeze
    READINGS = { cpu_percent: "CPU", memory_percent: "Memory", disk_percent: "Disk" }.freeze

    class << self
      def status_plugin_present?
        defined?(RubylodeStatus::Registry) ? true : false
      end

      # Called once every plugin has loaded (see init.rb). Returns whether the widget was registered.
      def register_with_status_plugin
        return false unless status_plugin_present?

        RubylodeStatus::Registry.register(
          key: KEY,
          title: -> { Settings.current.block_title },
          path: PAGE_PATH,
          data: -> { data },
          partial: PARTIAL,
          visibility: -> { Settings.current.visibility }
        )
        true
      end

      def data(settings = Settings.current)
        return { state: "unknown", summary: I18n.t("rubylode_beszel.status.not_set_up"), items: [] } unless settings.configured?

        report = SystemStatus.safe_report(settings)
        return { state: "unknown", summary: report.summary, items: [] } if report.unavailable?

        items = report.systems.map { |system| item_for(system) }
        { state: block_state(report.systems, items), summary: summary_for(report.systems), items: items }
      end

      private

      def item_for(system)
        state = ITEM_STATES.fetch(system.state)
        detail = system.state == :paused ? I18n.t("rubylode_beszel.status.paused") : nil
        if system.state == :up && (reading = worst_reading(system))
          state = "warning"
          detail = I18n.t("rubylode_beszel.status.usage_detail", resource: reading.first, percent: UsageLevel.clamp(reading.last))
        end
        { name: system.name, state: state, detail: detail }
      end

      # The highest reading at or above the warning level, as [label, percent], or nil.
      def worst_reading(system)
        readings = READINGS.filter_map { |field, label| [label, system[field]] unless system[field].nil? }
        label, percent = readings.max_by(&:last)
        label && percent >= UsageLevel::WARNING_PERCENT ? [label, percent] : nil
      end

      def block_state(systems, items)
        counted = systems.select { |system| %i[up down].include?(system.state) }
        return "unknown" if counted.empty?

        down = counted.count { |system| system.state == :down }
        return "down" if down == counted.size
        return "warning" if down.positive? || items.any? { |item| item[:state] == "warning" }

        "ok"
      end

      def summary_for(systems)
        counted = systems.select { |system| %i[up down].include?(system.state) }
        return I18n.t("rubylode_beszel.status.no_servers") if counted.empty?

        up = counted.count { |system| system.state == :up }
        I18n.t("rubylode_beszel.status.servers_up", up: up, count: counted.size)
      end
    end
  end
end
