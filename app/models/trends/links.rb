# frozen_string_literal: true

class Trends::Links
  PREFIX               = 'trending_links'
  EXPIRE_HISTORY_AFTER = 7.days.seconds

  include Redisable

  class Link < ActiveModelSerializers::Model
    attributes :id, :provider, :preview_card

    delegate :title, :description, :url, :provider_name,
             :provider_url, :author_name, :author_url,
             :image, :width, :height, :blurhash, to: :preview_card

    def history
      (0...7).map do |i|
        day = i.days.ago.beginning_of_day.to_i

        {
          day: day.to_s,
          accounts: Redis.current.pfcount("activity:links:#{id}:#{day}:accounts").to_s,
        }
      end
    end
  end

  def add(link_id, account_id)
    increment_unique_use!(link_id, account_id)
    increment_use!(link_id)
  end

  def get(limit, filtered: true)
    link_ids = redis.zrevrange(filtered ? "#{PREFIX}:allowed" : "#{PREFIX}:all", 0, limit).map(&:to_i)

    preview_cards = PreviewCard.where(id: link_ids).index_by(&:id)
    providers     = providers_for(preview_cards.values.map(&:domain))

    link_ids.map do |link_id|
      preview_card = preview_cards[link_id]

      next if preview_card.nil?

      provider = provider_for(providers, preview_card.domain)

      Link.new(
        id: link_id,
        preview_card: preview_card,
        provider: provider
      )
    end
  end

  def calculate(time = Time.now.utc)
    link_ids      = (redis.smembers("#{PREFIX}:used:#{time.beginning_of_day.to_i}") + redis.zrange(PREFIX, 0, -1)).uniq.map(&:to_i)
    preview_cards = PreviewCard.where(id: link_ids).index_by(&:id)
    providers     = providers_for(preview_cards.values.map(&:domain))

    link_ids.each do |link_id|
      preview_card = preview_cards[link_id]

      next if preview_card.nil?

      provider  = provider_for(providers, preview_card.domain)
      expected  = redis.pfcount("activity:links:#{link_id}:#{(time - 1.day).beginning_of_day.to_i}:accounts").to_f
      expected  = 1.0 if expected.zero?
      observed  = redis.pfcount("activity:links:#{link_id}:#{time.beginning_of_day.to_i}:accounts").to_f

      score = begin
        if expected > observed
          0
        else
          ((observed - expected)**2) / expected
        end
      end

      if score.zero?
        redis.zrem("#{PREFIX}:all", link_id)
        redis.zrem("#{PREFIX}:allowed", link_id)
      else
        redis.zadd("#{PREFIX}:all", score, link_id)
        redis.zadd("#{PREFIX}:allowed", score, link_id) if provider.present?
      end
    end

    #redis.zremrangebyscore("#{PREFIX}:all", '(0.3', '-inf')
    #redis.zremrangebyscore("#{PREFIX}:allowed", '(0.3', '-inf')
  end

  private

  def increment_use!(link_id, time = Time.now.utc)
    key = "#{PREFIX}:used:#{time.beginning_of_day.to_i}"

    redis.sadd(key, link_id)
    redis.expire(key, EXPIRE_HISTORY_AFTER)
  end

  def increment_unique_use!(link_id, account_id, time = Time.now.utc)
    key = "activity:links:#{link_id}:#{time.beginning_of_day.to_i}:accounts"

    redis.pfadd(key, account_id)
    redis.expire(key, EXPIRE_HISTORY_AFTER)
  end

  def providers_for(domains)
    Trends::AllowedDomain.where(domain: domains.flat_map { |domain| domain_variants(domain) }.uniq).index_by(&:domain)
  end

  def provider_for(providers, domain)
    domain_variants(domain).map { |variant| providers[variant] }.compact.first
  end

  def domain_variants(domain)
    segments = domain.split('.')
    segments.map.with_index { |_, i| segments[i..-1].join('.') }
  end
end
