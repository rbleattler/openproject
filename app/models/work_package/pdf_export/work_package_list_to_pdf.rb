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

# Exporter for work package table.
#
# It can optionally export a work package details list with
# - title
# - attribute table
# - description with optional embedded images
#
# When exporting with embedded images then the memory consumption can quickly
# grow beyond limits. Therefore we create multiple smaller PDFs that we finally
# merge do one file.

# require 'hexapdf'
require 'open3'

class WorkPackage::PDFExport::WorkPackageListToPdf < WorkPackage::Exports::QueryExporter
  include WorkPackage::PDFExport::Common
  include WorkPackage::PDFExport::Attachments
  include WorkPackage::PDFExport::OverviewTable
  include WorkPackage::PDFExport::WorkPackageDetail
  include WorkPackage::PDFExport::TableOfContents
  include WorkPackage::PDFExport::Page
  include WorkPackage::PDFExport::Style

  attr_accessor :pdf,
                :options

  def self.key
    :pdf
  end

  def initialize(object, options = {})
    super

    @total_page_nr = nil
    @page_count = 0
    @work_packages_per_batch = 100
    setup_page!
  end

  def export!
    file = render_work_packages query.results.work_packages
    success(file)
  rescue Prawn::Errors::CannotFit
    error(I18n.t(:error_pdf_export_too_many_columns))
  rescue StandardError => e
    Rails.logger.error { "Failed to generated PDF export: #{e} #{e.message}}." }
    error(I18n.t(:error_pdf_failed_to_export, error: e.message))
  end

  private

  def setup_page!
    self.pdf = get_pdf(current_language)

    configure_page_size!(with_descriptions? ? :portrait : :landscape)
  end

  def render_work_packages(work_packages, filename: "pdf_export")
    @id_wp_meta_map, flat_list = build_meta_infos_map(work_packages)
    file = render_work_packages_pdfs(flat_list, filename)
    if wants_total_page_nrs?
      @total_page_nr = @page_count
      @page_count = 0
      setup_page! # clear current pdf
      file = render_work_packages_pdfs(flat_list, filename)
    end
    file
  end

  def wants_total_page_nrs?
    true
  end

  def render_work_packages_pdfs(work_packages, filename)
    write_title!
    write_work_packages_toc! work_packages, @id_wp_meta_map if with_descriptions?
    write_work_packages_overview! work_packages, @id_wp_meta_map unless with_descriptions?
    if should_be_batched?(work_packages)
      render_batched(work_packages, filename)
    else
      render_pdf(work_packages, filename)
    end
  end

  def render_batched(work_packages, filename)
    @batches_count = work_packages.length.fdiv(@work_packages_per_batch).ceil
    batch_files = []
    (1..@batches_count).each do |batch_index|
      batch_work_packages = work_packages.paginate(page: batch_index, per_page: @work_packages_per_batch)
      batch_files.push render_pdf(batch_work_packages, "pdf_batch_#{batch_index}.pdf")
      setup_page!
    end
    merge_batched_pdfs(batch_files, filename)
  end

  def merge_batched_pdfs(batch_files, filename)
    return batch_files[0] if batch_files.length == 1

    # All internal link annotations are not copied over on merging
    # TODO: is there a way to preserve them?

    merged_pdf = Tempfile.new(filename)

    # We use the command line tool "pdfunite" for concatenating the PDFs.
    # That tool comes with the system package "poppler-utils" which we
    # fortunately already have installed for text extraction purposes.
    Open3.capture2e("pdfunite", *batch_files.map(&:path), merged_pdf.path)

    merged_pdf
  end

  def batch_supported?
    return @batch_supported if defined?(@batch_supported)

    @batch_supported =
      begin
        _, status = Open3.capture2e('pdfunite', '-h')
        status.success?
      rescue StandardError => e
        Rails.logger.error "Failed to test pdfunite version: #{e.message}"
        false
      end
  end

  def render_pdf(work_packages, filename)
    write_work_packages_details!(work_packages, @id_wp_meta_map) if with_descriptions?
    write_after_pages!
    file = Tempfile.new(filename)
    pdf.render_file(file.path)
    @page_count += pdf.page_count
    delete_all_resized_images
    file.close
    file
  end

  def write_after_pages!
    write_headers!
    write_footers!
  end

  def init_meta_infos_map_nodes(work_packages)
    infos_map = {}
    work_packages.each do |work_package|
      infos_map[work_package.id] = { level_path: [], level: 0, children: [], work_package: }
    end
    infos_map
  end

  def link_meta_infos_map_nodes(infos_map, work_packages)
    work_packages.reject { |wp| wp.parent_id.nil? }.each do |work_package|
      parent = infos_map[work_package.parent_id]
      infos_map[work_package.id][:parent] = parent
      parent[:children].push(infos_map[work_package.id]) if parent
    end
    infos_map
  end

  def fill_meta_infos_map_nodes(node, level_path, flat_list)
    node[:level_path] = level_path
    flat_list.push(node[:work_package]) unless node[:work_package].nil?
    index = 1
    node[:children].each do |sub|
      fill_meta_infos_map_nodes(sub, level_path + [index], flat_list)
      index += 1
    end
  end

  def build_flat_meta_infos_map(work_packages)
    infos_map = {}
    work_packages.each_with_index do |work_package, index|
      infos_map[work_package.id] = { level_path: [index + 1], level: 0, children: [], work_package: }
    end
    [infos_map, work_packages]
  end

  def build_meta_infos_map(work_packages)
    return build_flat_meta_infos_map(work_packages) unless query.show_hierarchies

    # build a quick access map for the hierarchy tree
    infos_map = init_meta_infos_map_nodes work_packages
    # connect parent and children (only wp available in the query)
    infos_map = link_meta_infos_map_nodes infos_map, work_packages
    # recursive travers creating level index path e.g. [1, 2, 1] from root nodes
    root_nodes = infos_map.values.select { |node| node[:parent].nil? }
    flat_list = []
    fill_meta_infos_map_nodes({ children: root_nodes }, [], flat_list)
    [infos_map, flat_list]
  end

  def should_be_batched?(work_packages)
    batch_supported? && with_descriptions? && with_attachments? && (work_packages.length > @work_packages_per_batch)
  end

  def project
    query.project
  end

  def title
    "#{heading}.pdf"
  end

  def heading
    title = query.new_record? ? I18n.t(:label_work_package_plural) : query.name

    if project
      "#{project} - #{title}"
    else
      title
    end
  end
end
