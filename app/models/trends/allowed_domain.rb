# frozen_string_literal: true

# == Schema Information
#
# Table name: trends_allowed_domains
#
#  id                :bigint(8)        not null, primary key
#  domain            :string           default(""), not null
#  icon_file_name    :string
#  icon_content_type :string
#  icon_file_size    :bigint(8)
#  icon_updated_at   :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class Trends::AllowedDomain < ApplicationRecord
  include DomainNormalizable
  include Attachmentable

  ICON_MIME_TYPES = %w(image/x-icon image/vnd.microsoft.icon image/png).freeze
  LIMIT = 1.megabyte

  validates :domain, presence: true, uniqueness: true, domain: true

  has_attached_file :icon, styles: { static: { format: 'png', convert_options: '-coalesce -strip' } }, validate_media_type: false
  validates_attachment :icon, content_type: { content_type: ICON_MIME_TYPES }, size: { less_than: LIMIT }
  remotable_attachment :icon, LIMIT
end
