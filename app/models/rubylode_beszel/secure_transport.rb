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

require "ipaddr"

module RubylodeBeszel
  # The rule for where credentials may travel: over https, or over plain http only to a loopback host or when the
  # administrator has said the network is internal (the "allow plain http" setting).
  module SecureTransport
    def self.loopback_host?(host)
      name = host.to_s.downcase.delete_prefix("[").delete_suffix("]")
      return true if name == "localhost"

      IPAddr.new(name).loopback?
    rescue IPAddr::Error
      false
    end

    def self.allowed?(uri, allow_plain_http:)
      return true if uri.scheme == "https"

      uri.scheme == "http" && (allow_plain_http || loopback_host?(uri.host))
    end
  end
end
