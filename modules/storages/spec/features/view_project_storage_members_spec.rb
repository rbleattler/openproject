#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
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

require_relative '../spec_helper'

# Setup storages in Project -> Settings -> File Storages
# This tests assumes that a Storage has already been setup
# in the Admin section, tested by admin_storage_spec.rb.
RSpec.describe(
  'Project storage members connection status view',
  js: true,
  with_flag: { storage_project_members_check: true }
) do
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin) }
  let(:connected_user) { create(:user) }
  let(:connected_no_permissions_user) { create(:user) }
  let(:disconnected_user) { create(:user) }

  let(:role_can_read_files) { create(:role, permissions: %i[manage_storages_in_project read_files]) }
  let(:role_cannot_read_files) { create(:role, permissions: %i[manage_storages_in_project]) }

  let(:oauth_application) { create(:oauth_application) }
  let(:storage) { create(:nextcloud_storage, :as_automatically_managed, oauth_application:) }
  let(:project) do
    create(:project,
           members: { user => role_can_read_files,
                      admin_user => role_cannot_read_files,
                      connected_user => role_can_read_files,
                      connected_no_permissions_user => role_cannot_read_files,
                      disconnected_user => role_can_read_files },
           enabled_module_names: %i[storages])
  end
  let!(:project_storage) { create(:project_storage, project:, storage:) }

  let(:oauth_client) { create(:oauth_client, integration: storage) }
  let(:oauth_client_token_connected_user) { create(:oauth_client_token, oauth_client:, user: connected_user) }
  let(:oauth_client_token_admin_user) { create(:oauth_client_token, oauth_client:, user: admin_user) }
  let(:oauth_client_token_no_permissions) { create(:oauth_client_token, oauth_client:, user: connected_no_permissions_user) }

  before do
    storage
    project
    oauth_client_token_connected_user
    oauth_client_token_admin_user
    oauth_client_token_no_permissions
    login_as user
  end

  it 'lists project members connection statuses' do
    # Go to Projects -> Settings -> File Storages
    visit project_settings_project_storages_path(project)

    expect(page).to have_title('File storages')
    expect(page).to have_text(storage.name)
    page.find('.icon.icon-group').click

    # Members check page
    expect(page).to have_current_path project_settings_project_storage_members_path(project_id: project,
                                                                                    project_storage_id: project_storage)

    [
      [user, 'Not connected'],
      [admin_user, 'Connected'],
      [connected_user, 'Connected'],
      [connected_no_permissions_user, 'User role has no storages permissions'],
      [disconnected_user, 'Not connected']
    ].each do |(principal, status)|
      expect(page).to have_selector("#member-#{principal.id} .name", text: principal.name)
      expect(page).to have_selector("#member-#{principal.id} .status", text: status)
    end
  end
end
