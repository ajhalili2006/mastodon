# frozen_string_literal: true

class REST::Trends::LinkSerializer < ActiveModel::Serializer
  include RoutingHelper

  attributes :url, :title, :description, :provider_name,
             :provider_url, :provider_icon, :author_name, :author_url,
             :width, :height, :image, :blurhash, :history

  def image
    object.preview_card.image? ? full_asset_url(object.preview_card.image.url(:original)) : nil
  end

  def provider_icon
    object.provider.icon? ? full_asset_url(object.provider.icon.url(:original)) : nil
  end
end
