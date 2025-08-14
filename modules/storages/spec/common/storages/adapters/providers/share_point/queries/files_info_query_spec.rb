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
require_module_spec_helper

module Storages
  module Adapters
    module Providers
      module SharePoint
        module Queries
          RSpec.describe FilesInfoQuery, :vcr, :webmock do
            let(:user) { create(:user) }
            let(:storage) { create(:share_point_storage, :sandbox, oauth_client_token_user: user) }
            let(:auth_strategy) { Registry["share_point.authentication.user_bound"].call(user, storage) }
            let(:input_data) { Input::FilesInfo.build(file_ids:).value! }

            subject(:query) { described_class.new(storage) }

            describe "#call" do
              it "responds with correct parameters" do
                expect(described_class).to respond_to(:call)

                method = described_class.method(:call)
                expect(method.parameters).to contain_exactly(%i[keyreq storage], %i[keyreq auth_strategy], %i[keyreq input_data])
              end

              context "without outbound request involved" do
                context "with an empty array of file ids" do
                  let(:file_ids) { [] }

                  it "returns an empty array" do
                    result = query.call(auth_strategy:, input_data:)

                    expect(result).to be_success
                    expect(result.value!).to eq([])
                  end
                end
              end

              context "with outbound requests successful", vcr: "share_point/files_info_query_success" do
                let(:drive_id) { "b!FeOZEMfQx0eGQKqVBLcP__BG8mq-4-9FuRqOyk3MXY87vnZ6fgfvQanZHX-XCAyw" }

                context "with an array of file ids" do
                  let(:file_ids) do
                    %W[
                      #{drive_id}||01ANJ53WYLXAJW5PXSCJB2CFCD42UPDKMI
                      #{drive_id}||01ANJ53W4ELLSQL3JZHNA2MHKKHKAUQWNS
                      #{drive_id}||01ANJ53W5UJK2CQO6IY5HLBVYBVNJ4TKHZ
                    ]
                  end

                  # rubocop:disable RSpec/ExampleLength
                  it "must return an array of file information when called" do
                    result = query.call(auth_strategy:, input_data:)
                    expect(result).to be_success

                    file_infos = result.value!
                    expect(file_infos.size).to eq(3)
                    expect(file_infos).to all(be_a(Results::StorageFileInfo))
                    expect(file_infos.map(&:to_h))
                      .to eq([
                               {
                                 status: "ok",
                                 status_code: 200,
                                 id: "01ANJ53WYLXAJW5PXSCJB2CFCD42UPDKMI",
                                 name: "Folder",
                                 size: 232311,
                                 mime_type: "application/x-op-directory",
                                 created_at: Time.parse("2023-12-14T14:53:00Z"),
                                 last_modified_at: Time.parse("2023-12-14T14:53:00Z"),
                                 owner_name: "Eric Schubert",
                                 owner_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 last_modified_by_name: "Eric Schubert",
                                 last_modified_by_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 permissions: nil,
                                 location: "/Shared%20Documents/Folder"
                               },
                               {
                                 status: "ok",
                                 status_code: 200,
                                 id: "01ANJ53W4ELLSQL3JZHNA2MHKKHKAUQWNS",
                                 name: "authurl.txt",
                                 size: 144,
                                 mime_type: "text/plain",
                                 created_at: Time.parse("2024-09-24T13:06:53Z"),
                                 last_modified_at: Time.parse("2024-09-24T13:06:55Z"),
                                 owner_name: "Eric Schubert",
                                 owner_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 last_modified_by_name: "Eric Schubert",
                                 last_modified_by_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 permissions: nil,
                                 location: "/Shared%20Documents/Folder/authurl.txt"
                               },
                               {
                                 status: "ok",
                                 status_code: 200,
                                 id: "01ANJ53W5UJK2CQO6IY5HLBVYBVNJ4TKHZ",
                                 name: "release_meme.jpg",
                                 size: 46264,
                                 mime_type: "image/jpeg",
                                 created_at: Time.parse("2024-02-20T14:26:07Z"),
                                 last_modified_at: Time.parse("2024-02-20T14:26:07Z"),
                                 owner_name: "Eric Schubert",
                                 owner_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 last_modified_by_name: "Eric Schubert",
                                 last_modified_by_id: "5b5a7dc4-4539-41ba-9fa9-100f0a26acb7",
                                 permissions: nil,
                                 location: "/Shared%20Documents/Folder/Nested%20Folder/release_meme.jpg"
                               }
                             ])
                  end
                  # rubocop:enable RSpec/ExampleLength
                end
              end

              context "with one outbound request returning not found", vcr: "share_point/files_info_query_one_not_found" do
                let(:drive_id) { "b!FeOZEMfQx0eGQKqVBLcP__BG8mq-4-9FuRqOyk3MXY87vnZ6fgfvQanZHX-XCAyw" }

                context "with an array of file ids" do
                  let(:file_ids) { %W[#{drive_id}||01ANJ53W4ELLSQL3JZHNA2MHKKHKAUQWNS #{drive_id}||not_existent] }

                  it "must return an array of file information when called" do
                    result = query.call(auth_strategy:, input_data:)
                    expect(result).to be_success
                    file_infos = result.value!

                    expect(file_infos.size).to eq(2)
                    expect(file_infos).to all(be_a(Results::StorageFileInfo))
                    expect(file_infos[1].id).to eq("not_existent")
                    expect(file_infos[1].status).to eq(:not_found)
                    expect(file_infos[1].status_code).to eq(404)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
