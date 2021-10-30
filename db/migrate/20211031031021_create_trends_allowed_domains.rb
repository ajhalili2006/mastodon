class CreateTrendsAllowedDomains < ActiveRecord::Migration[6.1]
  def change
    create_table :trends_allowed_domains do |t|
      t.string :domain, null: false, default: '', index: { unique: true }
      t.attachment :icon
      t.timestamps
    end
  end
end
