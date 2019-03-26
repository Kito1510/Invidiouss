def refresh_channels(db, logger, max_threads = 1, full_refresh = false)
  max_channel = Channel(Int32).new

  spawn do
    max_threads = max_channel.receive
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT id FROM channels ORDER BY updated") do |rs|
        rs.each do
          id = rs.read(String)

          if active_threads >= max_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              channel = fetch_channel(id, db, full_refresh)

              db.exec("UPDATE channels SET updated = $1, author = $2, deleted = false WHERE id = $3", Time.now, channel.author, id)
            rescue ex
              if ex.message == "Deleted or invalid channel"
                db.exec("UPDATE channels SET updated = $1, deleted = true WHERE id = $2", Time.now, id)
              end
              logger.write("#{id} : #{ex.message}\n")
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
    end
  end

  max_channel.send(max_threads)
end

def refresh_feeds(db, logger, max_threads = 1)
  max_channel = Channel(Int32).new

  spawn do
    max_threads = max_channel.receive
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT email FROM users") do |rs|
        rs.each do
          email = rs.read(String)
          view_name = "subscriptions_#{sha256(email)[0..7]}"

          if active_threads >= max_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              db.query("SELECT * FROM #{view_name} LIMIT 1") do |rs|
                # View doesn't contain same number of rows as ChannelVideo
                if ChannelVideo.from_rs(rs)[0]?.try &.to_a.size.try &.!= rs.column_count
                  db.exec("DROP MATERIALIZED VIEW #{view_name}")
                  raise "valid schema does not exist"
                end
              end

              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
            rescue ex
              # Create view if it doesn't exist
              if ex.message.try &.ends_with?("does not exist")
                # While iterating through, we may have an email stored from a deleted account
                if db.query_one?("SELECT true FROM users WHERE email = $1", email, as: Bool)
                  db.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
                  SELECT * FROM channel_videos WHERE \
                  ucid = ANY ((SELECT subscriptions FROM users WHERE email = E'#{email.gsub("'", "\\'")}')::text[]) \
                  ORDER BY published DESC;")
                  logger.write("CREATE #{view_name}\n")
                end
              else
                logger.write("REFRESH #{email} : #{ex.message}\n")
              end
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
    end
  end

  max_channel.send(max_threads)
end

def subscribe_to_feeds(db, logger, key, config)
  if config.use_pubsub_feeds
    spawn do
      loop do
        db.query_all("SELECT id FROM channels WHERE CURRENT_TIMESTAMP - subscribed > '4 days'") do |rs|
          rs.each do
            ucid = rs.read(String)
            response = subscribe_pubsub(ucid, key, config)

            if response.status_code >= 400
              logger.write("#{ucid} : #{response.body}\n")
            end
          end
        end

        sleep 1.minute
      end
    end
  end
end

def pull_top_videos(config, db)
  loop do
    begin
      top = rank_videos(db, 40)
    rescue ex
      next
    end

    if top.size > 0
      args = arg_array(top)
    else
      next
    end

    videos = [] of Video

    top.each do |id|
      begin
        videos << get_video(id, db)
      rescue ex
        next
      end
    end

    yield videos
    sleep 1.minute
  end
end

def pull_popular_videos(db)
  loop do
    subscriptions = db.query_all("SELECT channel FROM \
      (SELECT UNNEST(subscriptions) AS channel FROM users) AS d \
    GROUP BY channel ORDER BY COUNT(channel) DESC LIMIT 40", as: String)

    videos = db.query_all("SELECT DISTINCT ON (ucid) * FROM \
      channel_videos WHERE ucid IN (#{arg_array(subscriptions)}) \
    ORDER BY ucid, published DESC", subscriptions, as: ChannelVideo).sort_by { |video| video.published }.reverse

    yield videos
    sleep 1.minute
  end
end

def update_decrypt_function
  loop do
    begin
      decrypt_function = fetch_decrypt_function
    rescue ex
      next
    end

    yield decrypt_function
    sleep 1.minute
  end
end

def find_working_proxies(regions)
  loop do
    regions.each do |region|
      proxies = get_proxies(region).first(20)
      proxies = proxies.map { |proxy| {ip: proxy[:ip], port: proxy[:port]} }
      # proxies = filter_proxies(proxies)

      yield region, proxies
    end

    sleep 1.minute
  end
end
