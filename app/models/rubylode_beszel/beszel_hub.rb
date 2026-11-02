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

require "net/http"
require "json"

module RubylodeBeszel
  # Asks a Beszel hub (which is a PocketBase app) for its servers: it signs in with an email and password through the
  # "users" collection's auth endpoint, then lists the "systems" collection with the token it got back.
  #
  # Only the fields the page needs are requested, so a server's address never leaves the hub. The email and the password are
  # held in memory for the request: they are not logged, and both are scrubbed from every error message.
  # The answer is a list of plain hashes: name, status, updated, cpu, memory, disk.
  class BeszelHub
    class Unavailable < StandardError; end

    SIGN_IN_PATH = "/api/collections/users/auth-with-password".freeze
    LIST_PATH = "/api/collections/systems/records?perPage=500&sort=name&fields=name,status,updated,info".freeze

    MAXIMUM_REDIRECTS = 3

    # A credential whose variable name is not allowed (nil) or not set is read as empty, and the request is never made.
    # The variable is only read when its name starts with BESZEL_ (the configuration returns nil for any other name).
    def self.from_configuration(configuration)
      new(url: configuration.hub_url,
          email: read_variable(configuration.email_environment_variable),
          password: read_variable(configuration.password_environment_variable),
          timeout_seconds: configuration.timeout_seconds,
          credential_names: [configuration.email_environment_variable, configuration.password_environment_variable],
          allowed_hosts: configuration.allowed_hosts,
          allow_plain_http: configuration.allow_plain_http?)
    end

    def self.read_variable(name)
      name.to_s.match?(Configuration::ENVIRONMENT_VARIABLE_PATTERN) ? ENV[name].to_s : ""
    end

    # http_client is called with (method, url, headers, body_or_nil) and returns [status_code, body_text, location_or_nil].
    # The credentials only go to the hub's own host (and the allowed_hosts a redirect may lead to), and over https unless
    # the host is loopback or allow_plain_http is true.
    def initialize(url:, email:, password:, timeout_seconds: 2, credential_names: [], allowed_hosts: [], allow_plain_http: false, http_client: nil)
      @url = url.to_s.chomp("/")
      @email = email
      @password = password
      @timeout_seconds = timeout_seconds
      @credential_names = credential_names
      @allowed_hosts = allowed_hosts.map { |host| host.to_s.downcase }
      @allow_plain_http = allow_plain_http
      @http_client = http_client || method(:fetch_over_http)
    end

    def call
      raise Unavailable, credentials_missing_message if @email.empty? || @password.empty?
      raise Unavailable, I18n.t("rubylode_beszel.errors.insecure_connection") unless transport_allowed?(URI(@url))

      records = list_systems(sign_in)
      records.map { |record| summarize(record) }
    rescue Unavailable => error
      raise Unavailable, scrub(error.message)
    rescue StandardError => error
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_unreachable", error_class: error.class)
    end

    private

    def sign_in
      body = JSON.generate("identity" => @email, "password" => @password)
      status, text = request(:post, "#{@url}#{SIGN_IN_PATH}", { "Content-Type" => "application/json" }, body)
      raise Unavailable, I18n.t("rubylode_beszel.errors.sign_in_refused") if [400, 401, 403].include?(status)
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_status", status: status) unless status == 200

      token = JSON.parse(text)["token"].to_s
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_answer_unreadable") if token.empty?

      token
    rescue JSON::ParserError
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_answer_unreadable")
    end

    def list_systems(token)
      status, text = request(:get, "#{@url}#{LIST_PATH}", { "Authorization" => token }, nil)
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_status", status: status) unless status == 200

      items = JSON.parse(text)["items"]
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_answer_unreadable") unless items.is_a?(Array)

      items
    rescue JSON::ParserError
      raise Unavailable, I18n.t("rubylode_beszel.errors.hub_answer_unreadable")
    end

    # One request, following a redirect only to the hub's own host or an allowed host, and only over a connection that
    # may carry credentials. Anything else stops here, before the credentials are sent a second time.
    def request(method, url, headers, body)
      MAXIMUM_REDIRECTS.downto(0) do |redirects_left|
        status, text, location = @http_client.call(method, url, headers, body)
        return [status, text] unless [301, 302, 307, 308].include?(status) && location

        raise Unavailable, I18n.t("rubylode_beszel.errors.redirect_refused") if redirects_left.zero?

        target = URI.join(url, location)
        raise Unavailable, I18n.t("rubylode_beszel.errors.redirect_refused") unless trusted_host?(target) && transport_allowed?(target)

        url = target.to_s
      end
    end

    def trusted_host?(uri)
      host = uri.host.to_s.downcase
      host == URI(@url).host.to_s.downcase || @allowed_hosts.include?(host)
    end

    def transport_allowed?(uri)
      SecureTransport.allowed?(uri, allow_plain_http: @allow_plain_http)
    end

    def summarize(record)

      info = record["info"].is_a?(Hash) ? record["info"] : {}
      { "name" => record["name"].to_s,
        "status" => record["status"].to_s,
        "updated" => record["updated"].to_s,
        "cpu" => number_or_nil(info["cpu"]),
        "memory" => number_or_nil(info["mp"]),
        "disk" => number_or_nil(info["dp"]) }
    end

    def number_or_nil(value)
      value.is_a?(Numeric) ? value.to_f : nil
    end

    def credentials_missing_message
      names = @credential_names.map(&:to_s).reject(&:empty?)
      base = I18n.t("rubylode_beszel.errors.credentials_missing")
      names.empty? ? base : "#{base} (#{names.join(', ')})"
    end

    def scrub(message)
      [@email, @password].reject(&:empty?).reduce(message) { |text, secret| text.gsub(secret, "[filtered]") }
    end

    def fetch_over_http(method, url, headers, body)
      uri = URI(url)
      request = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
      headers.each { |name, value| request[name] = value }
      request.body = body if body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                     open_timeout: @timeout_seconds, read_timeout: @timeout_seconds) do |http|
        http.request(request)
      end
      [response.code.to_i, response.body.to_s, response["location"]]
    end
  end
end
