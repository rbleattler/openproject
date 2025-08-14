# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
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
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Projects::Exports::PDFExport
  module Report
    def render_report(projects, info_map)
      projects.each do |project|
        write_optional_page_break
        write_project_detail(project, info_map[project.id])
      end
    end

    def write_project_detail(project, info_map_entry)
      info_map_entry[:page_number] = current_page_nr
      with_margin(styles.project_margins) do
        write_project_title(project, info_map_entry[:level_path])
        write_project_detail_content(project)
      end
    end

    def write_project_title(project, level_path)
      text_style = styles.project_title
      with_margin(styles.project_title_margins) do
        link_target_at_current_y(project.id)
        level_string_width = write_project_level(level_path, text_style)
        pdf.indent(level_string_width) do
          pdf.formatted_text([text_style.merge({ text: project.name, link: url_helpers.project_url(project) })])
        end
      end
    end

    def write_project_level(level_path, text_style)
      return 0 if level_path.empty?

      level_string = "#{level_path.join('.')}. "
      level_string_width = measure_text_width(level_string, text_style)
      pdf.float { pdf.formatted_text([text_style.merge({ text: level_string })]) }
      level_string_width
    end

    def selects
      query.selects.reject { |s| s.is_a?(Queries::Selects::NotExistingSelect) }
    end

    def write_project_detail_content(project)
      export_selects = selects
      return if export_selects.empty?

      entries = []
      export_selects.each do |select|
        entries = process_select(project, select, entries)
      end
      write_table_entries(entries) unless entries.empty?
    end

    def process_select(project, select, entries)
      if custom_field_select?(select)
        process_custom_field_select(project, select, entries)
      elsif project_phase_select?(select)
        process_project_phase_select(project, select, entries)
      elsif can_view_attribute?(project, select.attribute)
        process_attribute_select(project, select, entries)
      else
        entries
      end
    end

    def process_custom_field_select(project, select, entries)
      return entries unless custom_field_active_in_project?(project, select.custom_field)

      if select.custom_field.formattable?
        write_table_entries(entries) unless entries.empty?
        write_formattable_custom_field(project, select.custom_field)
        []
      else
        entry = table_entry(project, "cf_#{select.custom_field.id}", select.caption)
        entries.push(entry) if entry
        entries
      end
    end

    def process_project_phase_select(project, select, entries)
      entry = user_can_view_project_phases?(project) ? table_entry_project_phase(project, select) : nil
      entries.push(entry) if entry
      entries
    end

    def process_attribute_select(project, select, entries)
      if attribute_formattable?(select.attribute)
        write_table_entries(entries) unless entries.empty?
        write_formattable_attribute(project, select.attribute, select.caption)
        []
      else
        entry = table_entry(project, select.attribute, select.caption)
        entries.push(entry) if entry
        entries
      end
    end

    def project_phase_select?(select)
      select.is_a?(::Queries::Projects::Selects::ProjectPhase)
    end

    def table_entry_project_phase(project, select)
      phase = project.phases.active.find_by(definition: select.project_phase_definition)
      return nil if phase.nil?

      [
        { content: select.caption }.merge(styles.project_attributes_table_label_cell),
        format_phase_value(phase)
      ]
    end

    def format_phase_value(phase)
      start = if phase.start_date.present?
                format_date(phase.start_date)
              else
                I18n.t("js.label_no_start_date")
              end

      finish = if phase.finish_date.present?
                 format_date(phase.finish_date)
               else
                 I18n.t("js.label_no_due_date")
               end

      "#{start} - #{finish}"
    end

    def table_entry(project, value_name, caption)
      value = format_attribute(project, value_name, :pdf)
      return nil if hide_empty_attributes? && value.blank?

      value = make_link_href_cell(url_helpers.project_url(project), value) if value_name == :id
      [
        { content: caption }.merge(styles.project_attributes_table_label_cell),
        value || ""
      ]
    end

    def can_view_attribute?(_project, attribute)
      attribute && %i[name favored].exclude?(attribute)
    end

    def user_can_view_project_phases?(project)
      User.current.allowed_in_project?(:view_project_phases, project) && project.phases.active.any?
    end

    def attribute_formattable?(attribute)
      %i[description status_explanation].include? attribute
    end

    def custom_field_select?(select)
      select.is_a?(::Queries::Projects::Selects::CustomField)
    end

    def custom_field_active_in_project?(project, custom_field)
      custom_field.is_for_all? ||
        project.project_custom_field_project_mappings.exists?(custom_field_id: custom_field.id)
    end

    def write_formattable_attribute(project, attribute, caption)
      write_project_markdown project.try(attribute), caption
    end

    def write_formattable_custom_field(project, custom_field)
      custom_field_value = project.custom_value_for(custom_field.id)
      write_project_markdown custom_field_value.value, custom_field.name
    end

    def write_project_markdown(value, caption)
      return if hide_empty_attributes? && value.blank?

      write_markdown_label(caption)
      value = Prawn::Text::NBSP if value.blank?
      with_margin(styles.project_markdown_margins) do
        write_markdown!(value, styles.project_markdown_styling_yml)
      end
    end

    def write_markdown_label(caption)
      with_margin(styles.project_markdown_label_margins) do
        pdf.formatted_text([styles.project_markdown_label.merge({ text: caption })])
      end
    end

    def write_table_entries(row_entries)
      return if row_entries.empty?

      rows = if attributes_table_4_column?
               0.step(row_entries.length - 1, 2).map do |i|
                 row_entries[i] + (row_entries[i + 1] || ["", ""])
               end
             else
               row_entries
             end

      pdf.table(
        rows,
        column_widths: attributes_table_column_widths,
        cell_style: styles.project_attributes_table_cell.merge({ inline_format: true })
      )
    end

    def attributes_table_4_column?
      true
    end

    def hide_empty_attributes?
      true
    end

    def attributes_table_column_widths
      widths = if attributes_table_4_column?
                 # label | value | label | value
                 [1.5, 2.0, 1.5, 2.0]
               else
                 # label | value
                 [1.0, 3.0]
               end
      ratio = pdf.bounds.width / widths.sum
      widths.map { |w| w * ratio }
    end
  end
end
