module YouTubeStructs
  # Struct to represent an InnerTube `"channelRenderer"`
  #
  # A channelRenderer renders a channel to click on within the YouTube and Invidious UI. It is **not**
  # the channel page itself.
  #
  # See specs for example JSON response
  #
  # `channelRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  struct ChannelRenderer
    include DB::Serializable

    property author : String
    property ucid : String
    property author_thumbnail : String
    property subscriber_count : Int32
    property video_count : Int32
    property description_html : String
    property auto_generated : Bool

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "type", "channel"
        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "authorThumbnails" do
          json.array do
            qualities = {32, 48, 76, 100, 176, 512}

            qualities.each do |quality|
              json.object do
                json.field "url", self.author_thumbnail.gsub(/=\d+/, "=s#{quality}")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end

        json.field "autoGenerated", self.auto_generated
        json.field "subCount", self.subscriber_count
        json.field "videoCount", self.video_count

        json.field "description", html_to_content(self.description_html)
        json.field "descriptionHtml", self.description_html
      end
    end

    def to_json(locale, json : JSON::Builder | Nil = nil)
      if json
        to_json(locale, json)
      else
        JSON.build do |json|
          to_json(locale, json)
        end
      end
    end
  end
end