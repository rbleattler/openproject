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

require "spec_helper"

RSpec.describe "My account session management", :js, :selenium do
  include Redmine::I18n
  let(:user) { create(:user) }

  let(:old_session_time) { 5.days.ago }
  let(:session_data) do
    { browser: "Mozilla Firefox", browser_version: "12.3", platform: "Linux", updated_at: old_session_time }
  end

  let!(:plain_session) { create(:user_session, user:, data: session_data) }
  let!(:user_session) { Sessions::UserSession.find_by(session_id: plain_session.session_id) }

  let!(:autologin_token) do
    create(:autologin_token,
           user:,
           data: { browser: "Firefox", browser_version: "142", platform: "macOS" },
           created_at: 3.days.ago,
           expires_on: 4.days.from_now)
  end

  before do
    login_as(user)
    Sessions::UserSession.where(id: user_session.id).update_all(updated_at: 5.days.ago)
    visit my_account_path
    click_on "Session management"
  end

  it "can list and terminate sessions and remembered devices" do
    page.within_test_selector("Users::Sessions::TableComponent") do
      # Current session + old session + remembered device
      expect(page).to have_css(".session-row", count: 3)

      trs = page.all(".session-row")

      # Current session
      expect(trs[0]).to have_text(I18n.t("users.sessions.current"))
      expect(trs[0]).to have_text("unknown browser")
      expect(trs[0]).to have_text("unknown operating system")
      expect(trs[0]).to have_no_test_selector("session-revoke-button")

      # Old session
      expect(trs[1]).to have_text("Mozilla Firefox (Version 12.3)")
      expect(trs[1]).to have_text("Linux")
      expect(trs[1]).to have_text format_time(old_session_time)
      expect(trs[1]).to have_test_selector("session-revoke-button")

      # Remembered device (token)
      expect(trs[2]).to have_text("Firefox (Version 142)")
      expect(trs[2]).to have_text("macOS")
      expect(trs[2]).to have_text(format_time(autologin_token.created_at))
      expect(trs[2]).to have_test_selector("session-revoke-button")

      # Revoke the old session
      within trs[1] do
        find_test_selector("session-revoke-button").click
      end
    end

    page.driver.browser.switch_to.alert.accept

    page.within_test_selector("Users::Sessions::TableComponent") do
      trs = page.all(".session-row")
      # Revoke the remembered device
      within trs[1] do
        find_test_selector("session-revoke-button").click
      end
    end

    page.driver.browser.switch_to.alert.accept

    page.within_test_selector("Users::Sessions::TableComponent") do
      # Only current session remains
      expect(page).to have_css(".session-row", count: 1)
    end

    # Both old session and token are gone
    expect { user_session.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect { autologin_token.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
