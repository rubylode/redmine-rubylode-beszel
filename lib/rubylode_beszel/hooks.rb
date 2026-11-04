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
  # Puts the status block where the settings ask for it: Redmine's welcome (Home) page, the project Overview page, and every
  # page whose path matches the list of paths (when "Pages matching these paths" is checked). The block is the same partial as everywhere
  # else, so permission, caching and the unavailable fallback are the same too.
  class Hooks < Redmine::Hook::ViewListener
    def view_welcome_index_left(context)
      render_on_welcome_page(context, "left")
    end

    def view_welcome_index_right(context)
      render_on_welcome_page(context, "right")
    end

    def view_projects_show_left(context)
      render_on_project_overview(context, "left")
    end

    def view_projects_show_right(context)
      render_on_project_overview(context, "right")
    end

    # The page's head is drawn before the body hook below runs, so a page that is going to get the block through the list of paths
    # takes the stylesheet here.
    def view_layouts_base_html_head(context)
      return "" unless path_matches?(context)

      context[:hook_caller].stylesheet_link_tag("rubylode_beszel", plugin: "redmine_rubylode_beszel")
    end

    # Runs on every page; draws nothing unless a path pattern matches and the block is not already on the page.
    def view_layouts_base_content(context)
      return "" unless path_matches?(context) && !already_rendered?(context[:hook_caller])

      context[:hook_caller].render(partial: "rubylode_beszel/status", locals: { compact: true })
    end

    private

    # Whether the list of paths asks for the block on this request. Anyone may be asked: the partial decides who sees it.
    def path_matches?(context)
      patterns = RubylodeBeszel::Settings.current.matching_page_patterns
      request = context[:request]
      return false if patterns.empty? || request.nil? || !request.get?

      path = request.path.delete_prefix(Redmine::Utils.relative_url_root.to_s)
      RubylodeBeszel::PathMatcher.match?(patterns, path)
    end

    def render_on_welcome_page(context, column)
      configuration = RubylodeBeszel::Settings.current
      return "" unless configuration.show_on_welcome_page? && configuration.welcome_page_column == column

      context[:hook_caller].render(partial: "rubylode_beszel/status")
    end

    def render_on_project_overview(context, column)
      configuration = RubylodeBeszel::Settings.current
      return "" unless configuration.show_on_project_overview? && configuration.project_overview_column == column

      context[:hook_caller].render(partial: "rubylode_beszel/status")
    end

    def already_rendered?(view)
      view.instance_variable_get(:@rubylode_beszel_rendered)
    end
  end
end
