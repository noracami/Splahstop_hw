namespace :user_logs do
  desc "create logs"
  task :init => :environment do
    reviews = ([''] * 250).map {
      { content: Faker::Restaurant.review,
        created_at: Time.current,
        updated_at: Time.current}
    }
    5000.times do
      UserLog.insert_all(reviews)
    end
    p "#{UserLog.last.id} created."
  end

  desc "delete logs"
  task :delete => :environment do
    period = 10.minutes.ago
    counts = 0
    UserLog.where("updated_at < ?", period).limit(1001).find_in_batches do |rows|
      p cc = rows.last.id
      UserLog.delete(rows.map(&:id))
      # UserLog.destroy(rows.map(&:id))
      p UserLog.find_by(id: cc)
    end
  end
end
