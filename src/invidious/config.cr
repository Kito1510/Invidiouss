#
# This file contains the server config data structures and
# all the associated validation/parsing routines.
#

struct DBConfig
  include YAML::Serializable

  property user : String
  property password : String

  property host : String
  property port : Int32

  property dbname : String
end

class Config
  include YAML::Serializable

  property channel_threads : Int32 = 1           # Number of threads to use for crawling videos from channels (for updating subscriptions)
  property feed_threads : Int32 = 1              # Number of threads to use for updating feeds
  property output : String = "STDOUT"            # Log file path or STDOUT
  property log_level : LogLevel = LogLevel::Info # Default log level, valid YAML values are ints and strings, see src/invidious/helpers/logger.cr
  property db : DBConfig? = nil                  # Database configuration with separate parameters (username, hostname, etc)

  @[YAML::Field(converter: Config::URIConverter)]
  property database_url : URI = URI.parse("")      # Database configuration using 12-Factor "Database URL" syntax
  property decrypt_polling : Bool = true           # Use polling to keep decryption function up to date
  property full_refresh : Bool = false             # Used for crawling channels: threads should check all videos uploaded by a channel
  property https_only : Bool?                      # Used to tell Invidious it is behind a proxy, so links to resources should be https://
  property hmac_key : String?                      # HMAC signing key for CSRF tokens and verifying pubsub subscriptions
  property domain : String?                        # Domain to be used for links to resources on the site where an absolute URL is required
  property use_pubsub_feeds : Bool | Int32 = false # Subscribe to channels using PubSubHubbub (requires domain, hmac_key)
  property popular_enabled : Bool = true
  property captcha_enabled : Bool = true
  property login_enabled : Bool = true
  property registration_enabled : Bool = true
  property statistics_enabled : Bool = false
  property admins : Array(String) = [] of String
  property external_port : Int32? = nil

  property default_user_preferences : Preferences = Preferences.new

  property dmca_content : Array(String) = [] of String    # For compliance with DMCA, disables download widget using list of video IDs
  property check_tables : Bool = false                    # Check table integrity, automatically try to add any missing columns, create tables, etc.
  property cache_annotations : Bool = false               # Cache annotations requested from IA, will not cache empty annotations or annotations that only contain cards
  property banner : String? = nil                         # Optional banner to be displayed along top of page for announcements, etc.
  property hsts : Bool? = true                            # Enables 'Strict-Transport-Security'. Ensure that `domain` and all subdomains are served securely
  property disable_proxy : Bool? | Array(String)? = false # Disable proxying server-wide: options: 'dash', 'livestreams', 'downloads', 'local'

  @[YAML::Field(converter: Config::FamilyConverter)]
  property force_resolve : Socket::Family = Socket::Family::UNSPEC # Connect to YouTube over 'ipv6', 'ipv4'. Will sometimes resolve fix issues with rate-limiting (see https://github.com/ytdl-org/youtube-dl/issues/21729)
  property port : Int32 = 3000                                     # Port to listen for connections (overrided by command line argument)
  property host_binding : String = "0.0.0.0"                       # Host to bind (overrided by command line argument)
  property pool_size : Int32 = 100                                 # Pool size for HTTP requests to youtube.com and ytimg.com (each domain has a separate pool of `pool_size`)
  property use_quic : Bool = true                                  # Use quic transport for youtube api

  @[YAML::Field(converter: Config::StringToCookies)]
  property cookies : HTTP::Cookies = HTTP::Cookies.new               # Saved cookies in "name1=value1; name2=value2..." format
  property captcha_key : String? = nil                               # Key for Anti-Captcha
  property captcha_api_url : String = "https://api.anti-captcha.com" # API URL for Anti-Captcha

  def disabled?(option)
    case disabled = CONFIG.disable_proxy
    when Bool
      return disabled
    when Array
      if disabled.includes? option
        return true
      else
        return false
      end
    else
      return false
    end
  end

  def self.load
    # Load config from file or YAML string env var
    env_config_file = "INVIDIOUS_CONFIG_FILE"
    env_config_yaml = "INVIDIOUS_CONFIG"

    config_file = ENV.has_key?(env_config_file) ? ENV.fetch(env_config_file) : "config/config.yml"
    config_yaml = ENV.has_key?(env_config_yaml) ? ENV.fetch(env_config_yaml) : File.read(config_file)

    config = Config.from_yaml(config_yaml)

    # Update config from env vars (upcased and prefixed with "INVIDIOUS_")
    {% for ivar in Config.instance_vars %}
        {% env_id = "INVIDIOUS_#{ivar.id.upcase}" %}

        if ENV.has_key?({{env_id}})
            # puts %(Config.{{ivar.id}} : Loading from env var {{env_id}})
            env_value = ENV.fetch({{env_id}})
            success = false

            # Use YAML converter if specified
            {% ann = ivar.annotation(::YAML::Field) %}
            {% if ann && ann[:converter] %}
                puts %(Config.{{ivar.id}} : Parsing "#{env_value}" as {{ivar.type}} with {{ann[:converter]}} converter)
                config.{{ivar.id}} = {{ann[:converter]}}.from_yaml(YAML::ParseContext.new, YAML::Nodes.parse(ENV.fetch({{env_id}})).nodes[0])
                puts %(Config.{{ivar.id}} : Set to #{config.{{ivar.id}}})
                success = true

            # Use regular YAML parser otherwise
            {% else %}
                {% ivar_types = ivar.type.union? ? ivar.type.union_types : [ivar.type] %}
                # Sort types to avoid parsing nulls and numbers as strings
                {% ivar_types = ivar_types.sort_by { |ivar_type| ivar_type == Nil ? 0 : ivar_type == Int32 ? 1 : 2 } %}
                {{ivar_types}}.each do |ivar_type|
                    if !success
                        begin
                            # puts %(Config.{{ivar.id}} : Trying to parse "#{env_value}" as #{ivar_type})
                            config.{{ivar.id}} = ivar_type.from_yaml(env_value)
                            puts %(Config.{{ivar.id}} : Set to #{config.{{ivar.id}}} (#{ivar_type}))
                            success = true
                        rescue
                            # nop
                        end
                    end
                end
            {% end %}

            # Exit on fail
            if !success
                puts %(Config.{{ivar.id}} failed to parse #{env_value} as {{ivar.type}})
                exit(1)
            end
        end
    {% end %}

    # Build database_url from db.* if it's not set directly
    if config.database_url.to_s.empty?
      if db = config.db
        config.database_url = URI.new(
          scheme: "postgres",
          user: db.user,
          password: db.password,
          host: db.host,
          port: db.port,
          path: db.dbname,
        )
      else
        puts "Config : Either database_url or db.* is required"
        exit(1)
      end
    end

    return config
  end

  module URIConverter
    def self.to_yaml(value : URI, yaml : YAML::Nodes::Builder)
      yaml.scalar value.normalize!
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : URI
      if node.is_a?(YAML::Nodes::Scalar)
        URI.parse node.value
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module FamilyConverter
    def self.to_yaml(value : Socket::Family, yaml : YAML::Nodes::Builder)
      case value
      when Socket::Family::UNSPEC
        yaml.scalar nil
      when Socket::Family::INET
        yaml.scalar "ipv4"
      when Socket::Family::INET6
        yaml.scalar "ipv6"
      when Socket::Family::UNIX
        raise "Invalid socket family #{value}"
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Socket::Family
      if node.is_a?(YAML::Nodes::Scalar)
        case node.value.downcase
        when "ipv4"
          Socket::Family::INET
        when "ipv6"
          Socket::Family::INET6
        else
          Socket::Family::UNSPEC
        end
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module StringToCookies
    def self.to_yaml(value : HTTP::Cookies, yaml : YAML::Nodes::Builder)
      (value.map { |c| "#{c.name}=#{c.value}" }).join("; ").to_yaml(yaml)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : HTTP::Cookies
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      cookies = HTTP::Cookies.new
      node.value.split(";").each do |cookie|
        next if cookie.strip.empty?
        name, value = cookie.split("=", 2)
        cookies << HTTP::Cookie.new(name.strip, value.strip)
      end

      cookies
    end
  end
end
