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

class Meeting::AddToSection < ApplicationForm
  form do |meeting_form|
    meeting_form.autocompleter(
      name: :meeting_section_id,
      label: I18n.t("label_add_work_package_to_meeting_section_label"),
      caption: I18n.t("label_section_selection_caption"),
      input_width: :large,
      autocomplete_options: {
        decorated: true,
        defaultData: false,
        multiple: false,
        focus_directly: false,
        disabled: meeting.blank?,
        placeholder: placeholder_text,
        append_to: append_to_container
      }
    ) do |select|
      items.each do |item|
        select.option(
          value: item.id,
          label: option_title(item),
          selected: preselected_option.present? && item.id == preselected_option[:id]
        )
      end
    end
  end

  def initialize(wrapper_id: nil)
    super()

    @wrapper_id = wrapper_id
  end

  private

  delegate :meeting, to: :model

  def append_to_container
    @wrapper_id.nil? ? "body" : "##{@wrapper_id}"
  end

  def items
    items = []
    items.concat(meeting.sections) unless meeting.blank? || any_non_backlog_sections?
    items.push(meeting.backlog) if meeting.present?

    items
  end

  def option_title(item)
    return I18n.t("meeting_section.untitled_title") if item.title.blank? && !item.backlog?

    item.title
  end

  def preselected_option
    return if meeting.blank?

    if meeting.recurring?
      without_backlog = items.reject(&:backlog?)
      item = without_backlog.last
    else
      item = meeting.backlog
    end

    item
  end

  def any_non_backlog_sections?
    meeting.sections.none? || (meeting.sections.one? && meeting.sections.first.title.blank?)
  end

  def placeholder_text
    I18n.t("placeholder_section_select_meeting_first") if meeting.blank?
  end
end
