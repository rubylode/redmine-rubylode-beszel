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

class RubylodeBeszel::SecureTransportTest < ActiveSupport::TestCase
  def allowed?(url, allow_plain_http: false)
    RubylodeBeszel::SecureTransport.allowed?(URI(url), allow_plain_http: allow_plain_http)
  end

  test "https is always allowed" do
    assert allowed?("https://beszel.example.com")
  end

  test "plain http is refused for a named host unless the setting allows it" do
    refute allowed?("http://beszel.example.com")
    assert allowed?("http://beszel.example.com", allow_plain_http: true)
  end

  test "plain http is allowed to loopback hosts" do
    %w[http://localhost:8090 http://127.0.0.1:8090 http://127.0.0.5 http://[::1]:8090].each do |url|
      assert allowed?(url), url
    end
  end

  test "other schemes are never allowed" do
    refute allowed?("ftp://beszel.example.com", allow_plain_http: true)
  end

  test "an address that merely looks like localhost is not loopback" do
    refute allowed?("http://localhost.example.com")
    refute allowed?("http://10.0.0.5")
  end
end
