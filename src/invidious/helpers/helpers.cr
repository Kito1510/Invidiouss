require "./macros"

struct Nonce
  include DB::Serializable

  property nonce : String
  property expire : Time
end

struct SessionId
  include DB::Serializable

  property id : String
  property email : String
  property issued : String
end

struct Annotation
  include DB::Serializable

  property id : String
  property annotations : String
end

def login_req(f_req)
  data = {
    # Unfortunately there's not much information available on `bgRequest`; part of Google's BotGuard
    # Generally this is much longer (>1250 characters), see also
    # https://github.com/ytdl-org/youtube-dl/commit/baf67a604d912722b0fe03a40e9dc5349a2208cb .
    # For now this can be empty.
    "bgRequest"       => %|["identifier",""]|,
    "pstMsg"          => "1",
    "checkConnection" => "youtube",
    "checkedDomains"  => "youtube",
    "hl"              => "en",
    "deviceinfo"      => %|[null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[]]]|,
    "f.req"           => f_req,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
    # "cookiesDisabled" => "false",
    # "gmscoreversion"  => "undefined",
    # "continue"        => "https://accounts.google.com/ManageAccount",
    # "azt"             => "",
    # "bgHash"          => "",
  }

  return HTTP::Params.encode(data)
end

def html_to_content(description_html : String)
  description = description_html.gsub(/(<br>)|(<br\/>)/, {
    "<br>":  "\n",
    "<br/>": "\n",
  })

  if !description.empty?
    description = XML.parse_html(description).content.strip("\n ")
  end

  return description
end

def extract_videos(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  extract_items(initial_data, author_fallback, author_id_fallback).select(&.is_a?(SearchVideo)).map(&.as(SearchVideo))
end

def extract_item(item : JSON::Any, author_fallback : String? = nil, author_id_fallback : String? = nil)
  if i = (item["videoRenderer"]? || item["gridVideoRenderer"]?)
    video_id = i["videoId"].as_s
    title = i["title"].try { |t| t["simpleText"]?.try &.as_s || t["runs"]?.try &.as_a.map(&.["text"].as_s).join("") } || ""

    author_info = i["ownerText"]?.try &.["runs"]?.try &.as_a?.try &.[0]?
    author = author_info.try &.["text"].as_s || author_fallback || ""
    author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_id_fallback || ""

    published = i["publishedTimeText"]?.try &.["simpleText"]?.try { |t| decode_date(t.as_s) } || Time.local
    view_count = i["viewCountText"]?.try &.["simpleText"]?.try &.as_s.gsub(/\D+/, "").to_i64? || 0_i64
    description_html = i["descriptionSnippet"]?.try { |t| parse_content(t) } || ""
    length_seconds = i["lengthText"]?.try &.["simpleText"]?.try &.as_s.try { |t| decode_length_seconds(t) } ||
                     i["thumbnailOverlays"]?.try &.as_a.find(&.["thumbnailOverlayTimeStatusRenderer"]?).try &.["thumbnailOverlayTimeStatusRenderer"]?
                       .try &.["text"]?.try &.["simpleText"]?.try &.as_s.try { |t| decode_length_seconds(t) } || 0

    live_now = false
    premium = false

    premiere_timestamp = i["upcomingEventData"]?.try &.["startTime"]?.try { |t| Time.unix(t.as_s.to_i64) }

    i["badges"]?.try &.as_a.each do |badge|
      b = badge["metadataBadgeRenderer"]
      case b["label"].as_s
      when "LIVE NOW"
        live_now = true
      when "New", "4K", "CC"
        # TODO
      when "Premium"
        # TODO: Potentially available as i["topStandaloneBadge"]["metadataBadgeRenderer"]
        premium = true
      else nil # Ignore
      end
    end

    SearchVideo.new({
      title:              title,
      id:                 video_id,
      author:             author,
      ucid:               author_id,
      published:          published,
      views:              view_count,
      description_html:   description_html,
      length_seconds:     length_seconds,
      live_now:           live_now,
      premium:            premium,
      premiere_timestamp: premiere_timestamp,
    })
  elsif i = item["channelRenderer"]?
    author = i["title"]["simpleText"]?.try &.as_s || author_fallback || ""
    author_id = i["channelId"]?.try &.as_s || author_id_fallback || ""

    author_thumbnail = i["thumbnail"]["thumbnails"]?.try &.as_a[0]?.try &.["url"]?.try &.as_s || ""
    subscriber_count = i["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s.try { |s| short_text_to_number(s.split(" ")[0]) } || 0

    auto_generated = false
    auto_generated = true if !i["videoCountText"]?
    video_count = i["videoCountText"]?.try &.["runs"].as_a[0]?.try &.["text"].as_s.gsub(/\D/, "").to_i || 0
    description_html = i["descriptionSnippet"]?.try { |t| parse_content(t) } || ""

    SearchChannel.new({
      author:           author,
      ucid:             author_id,
      author_thumbnail: author_thumbnail,
      subscriber_count: subscriber_count,
      video_count:      video_count,
      description_html: description_html,
      auto_generated:   auto_generated,
    })
  elsif i = item["gridPlaylistRenderer"]?
    title = i["title"]["runs"].as_a[0]?.try &.["text"].as_s || ""
    plid = i["playlistId"]?.try &.as_s || ""

    video_count = i["videoCountText"]["runs"].as_a[0]?.try &.["text"].as_s.gsub(/\D/, "").to_i || 0
    playlist_thumbnail = i["thumbnail"]["thumbnails"][0]?.try &.["url"]?.try &.as_s || ""

    SearchPlaylist.new({
      title:       title,
      id:          plid,
      author:      author_fallback || "",
      ucid:        author_id_fallback || "",
      video_count: video_count,
      videos:      [] of SearchPlaylistVideo,
      thumbnail:   playlist_thumbnail,
    })
  elsif i = item["playlistRenderer"]?
    title = i["title"]["simpleText"]?.try &.as_s || ""
    plid = i["playlistId"]?.try &.as_s || ""

    video_count = i["videoCount"]?.try &.as_s.to_i || 0
    playlist_thumbnail = i["thumbnails"].as_a[0]?.try &.["thumbnails"]?.try &.as_a[0]?.try &.["url"].as_s || ""

    author_info = i["shortBylineText"]?.try &.["runs"]?.try &.as_a?.try &.[0]?
    author = author_info.try &.["text"].as_s || author_fallback || ""
    author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_id_fallback || ""

    videos = i["videos"]?.try &.as_a.map do |v|
      v = v["childVideoRenderer"]
      v_title = v["title"]["simpleText"]?.try &.as_s || ""
      v_id = v["videoId"]?.try &.as_s || ""
      v_length_seconds = v["lengthText"]?.try &.["simpleText"]?.try { |t| decode_length_seconds(t.as_s) } || 0
      SearchPlaylistVideo.new({
        title:          v_title,
        id:             v_id,
        length_seconds: v_length_seconds,
      })
    end || [] of SearchPlaylistVideo

    # TODO: i["publishedTimeText"]?

    SearchPlaylist.new({
      title:       title,
      id:          plid,
      author:      author,
      ucid:        author_id,
      video_count: video_count,
      videos:      videos,
      thumbnail:   playlist_thumbnail,
    })
  elsif i = item["radioRenderer"]? # Mix
    # TODO
  elsif i = item["showRenderer"]? # Show
    # TODO
  elsif i = item["shelfRenderer"]?
  elsif i = item["horizontalCardListRenderer"]?
  elsif i = item["searchPyvRenderer"]? # Ad
  end
end

def extract_items(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  items = [] of SearchItem

  channel_v2_response = initial_data
    .try &.["continuationContents"]?
      .try &.["gridContinuation"]?
        .try &.["items"]?

  if channel_v2_response
    channel_v2_response.try &.as_a.each { |item|
      extract_item(item, author_fallback, author_id_fallback)
        .try { |t| items << t }
    }
  else
    initial_data.try { |t| t["contents"]? || t["response"]? }
      .try { |t| t["twoColumnBrowseResultsRenderer"]?.try &.["tabs"].as_a.select(&.["tabRenderer"]?.try &.["selected"].as_bool)[0]?.try &.["tabRenderer"]["content"] ||
        t["twoColumnSearchResultsRenderer"]?.try &.["primaryContents"] ||
        t["continuationContents"]? }
      .try { |t| t["sectionListRenderer"]? || t["sectionListContinuation"]? }
      .try &.["contents"].as_a
        .each { |c| c.try &.["itemSectionRenderer"]?.try &.["contents"].as_a
          .try { |t| t[0]?.try &.["shelfRenderer"]?.try &.["content"]["expandedShelfContentsRenderer"]?.try &.["items"].as_a ||
            t[0]?.try &.["gridRenderer"]?.try &.["items"].as_a || t }
          .each { |item|
            extract_item(item, author_fallback, author_id_fallback)
              .try { |t| items << t }
          } }
  end

  items
end

def check_enum(db, enum_name, struct_type = nil)
  return # TODO

  if !db.query_one?("SELECT true FROM pg_type WHERE typname = $1", enum_name, as: Bool)
    LOGGER.info("check_enum: CREATE TYPE #{enum_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{enum_name}.sql"))
    end
  end
end

def check_table(db, table_name, struct_type = nil)
  # Create table if it doesn't exist
  begin
    db.exec("SELECT * FROM #{table_name} LIMIT 0")
  rescue ex
    LOGGER.info("check_table: check_table: CREATE TABLE #{table_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{table_name}.sql"))
    end
  end

  return if !struct_type

  struct_array = struct_type.type_array
  column_array = get_column_array(db, table_name)
  column_types = File.read("config/sql/#{table_name}.sql").match(/CREATE TABLE public\.#{table_name}\n\((?<types>[\d\D]*?)\);/)
    .try &.["types"].split(",").map { |line| line.strip }.reject &.starts_with?("CONSTRAINT")

  return if !column_types

  struct_array.each_with_index do |name, i|
    if name != column_array[i]?
      if !column_array[i]?
        new_column = column_types.select { |line| line.starts_with? name }[0]
        LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
        db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
        next
      end

      # Column doesn't exist
      if !column_array.includes? name
        new_column = column_types.select { |line| line.starts_with? name }[0]
        db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
      end

      # Column exists but in the wrong position, rotate
      if struct_array.includes? column_array[i]
        until name == column_array[i]
          new_column = column_types.select { |line| line.starts_with? column_array[i] }[0]?.try &.gsub("#{column_array[i]}", "#{column_array[i]}_new")

          # There's a column we didn't expect
          if !new_column
            LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]}")
            db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

            column_array = get_column_array(db, table_name)
            next
          end

          LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
          db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")

          LOGGER.info("check_table: UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")
          db.exec("UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")

          LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
          db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

          LOGGER.info("check_table: ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")
          db.exec("ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")

          column_array = get_column_array(db, table_name)
        end
      else
        LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
        db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
      end
    end
  end

  return if column_array.size <= struct_array.size

  column_array.each do |column|
    if !struct_array.includes? column
      LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
      db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
    end
  end
end

def get_column_array(db, table_name)
  column_array = [] of String
  db.query("SELECT * FROM #{table_name} LIMIT 0") do |rs|
    rs.column_count.times do |i|
      column = rs.as(PG::ResultSet).field(i)
      column_array << column.name
    end
  end

  return column_array
end

def cache_annotation(db, id, annotations)
  if !CONFIG.cache_annotations
    return
  end

  body = XML.parse(annotations)
  nodeset = body.xpath_nodes(%q(/document/annotations/annotation))

  return if nodeset == 0

  has_legacy_annotations = false
  nodeset.each do |node|
    if !{"branding", "card", "drawer"}.includes? node["type"]?
      has_legacy_annotations = true
      break
    end
  end

  db.exec("INSERT INTO annotations VALUES ($1, $2) ON CONFLICT DO NOTHING", id, annotations) if has_legacy_annotations
end

def create_notification_stream(env, topics, connection_channel)
  connection = Channel(PQ::Notification).new(8)
  connection_channel.send({true, connection})

  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  since = env.params.query["since"]?.try &.to_i?
  id = 0

  if topics.includes? "debug"
    spawn do
      begin
        loop do
          time_span = [0, 0, 0, 0]
          time_span[rand(4)] = rand(30) + 5
          published = Time.utc - Time::Span.new(days: time_span[0], hours: time_span[1], minutes: time_span[2], seconds: time_span[3])
          video_id = TEST_IDS[rand(TEST_IDS.size)]

          video = get_video(video_id, PG_DB)
          video.published = published
          response = JSON.parse(video.to_json(locale))

          if fields_text = env.params.query["fields"]?
            begin
              JSONFilter.filter(response, fields_text)
            rescue ex
              env.response.status_code = 400
              response = {"error" => ex.message}
            end
          end

          env.response.puts "id: #{id}"
          env.response.puts "data: #{response.to_json}"
          env.response.puts
          env.response.flush

          id += 1

          sleep 1.minute
          Fiber.yield
        end
      rescue ex
      end
    end
  end

  spawn do
    begin
      if since
        topics.try &.each do |topic|
          case topic
          when .match(/UC[A-Za-z0-9_-]{22}/)
            PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid = $1 AND published > $2 ORDER BY published DESC LIMIT 15",
              topic, Time.unix(since.not_nil!), as: ChannelVideo).each do |video|
              response = JSON.parse(video.to_json(locale))

              if fields_text = env.params.query["fields"]?
                begin
                  JSONFilter.filter(response, fields_text)
                rescue ex
                  env.response.status_code = 400
                  response = {"error" => ex.message}
                end
              end

              env.response.puts "id: #{id}"
              env.response.puts "data: #{response.to_json}"
              env.response.puts
              env.response.flush

              id += 1
            end
          else
            # TODO
          end
        end
      end
    end
  end

  spawn do
    begin
      loop do
        event = connection.receive

        notification = JSON.parse(event.payload)
        topic = notification["topic"].as_s
        video_id = notification["videoId"].as_s
        published = notification["published"].as_i64

        if !topics.try &.includes? topic
          next
        end

        video = get_video(video_id, PG_DB)
        video.published = Time.unix(published)
        response = JSON.parse(video.to_json(locale))

        if fields_text = env.params.query["fields"]?
          begin
            JSONFilter.filter(response, fields_text)
          rescue ex
            env.response.status_code = 400
            response = {"error" => ex.message}
          end
        end

        env.response.puts "id: #{id}"
        env.response.puts "data: #{response.to_json}"
        env.response.puts
        env.response.flush

        id += 1
      end
    rescue ex
    ensure
      connection_channel.send({false, connection})
    end
  end

  begin
    # Send heartbeat
    loop do
      env.response.puts ":keepalive #{Time.utc.to_unix}"
      env.response.puts
      env.response.flush
      sleep (20 + rand(11)).seconds
    end
  rescue ex
  ensure
    connection_channel.send({false, connection})
  end
end

def extract_initial_data(body) : Hash(String, JSON::Any)
  return JSON.parse(body.match(/(window\["ytInitialData"\]|var\s*ytInitialData)\s*=\s*(?<info>{.*?});<\/script>/mx).try &.["info"] || "{}").as_h
end

def proxy_file(response, env)
  if response.headers.includes_word?("Content-Encoding", "gzip")
    Compress::Gzip::Writer.open(env.response) do |deflate|
      IO.copy response.body_io, deflate
    end
  elsif response.headers.includes_word?("Content-Encoding", "deflate")
    Compress::Deflate::Writer.open(env.response) do |deflate|
      IO.copy response.body_io, deflate
    end
  else
    IO.copy response.body_io, env.response
  end
end
