require "json"
require "uuid"

# Reads from the config file and returns a config object
# if the config file is not present, it will create a new one
# with the default values and return that
class AgentConfig
  include JSON::Serializable
  include JSON::Serializable::Unmapped

  property agent_name : String
  property agent_id : String
  property agent_personality : String
  property continuous_mode : Bool
  property speak_mode : Bool
  property fast_llm_model : String
  property smart_llm_model : String
  property fast_token_limit : Int32
  property smart_token_limit : Int32
  property openai_api_key : String
  property elevenlabs_api_key : String
  property google_api_key : String
  property custom_search_engine_id : String
  property pinecone_api_key : String
  property pinecone_region : String
  property redis_host : String
  property redis_port : String
  property redis_password : String
  property wipe_redis_on_start : Bool
  property memory_index : String
  property memory_backend : String
  property is_default_settings : Bool = false
  property goals : Array(Goal) = [] of Goal
  property custom_local_storage_path : String = ""

  # Initializes the config object using some logic to determine if the config json is present
  # or if the defaults will need to be used. Run the agent the first time to have the config generated.
  def self.create_new_config_file_or_load_existing_config
    if Dir.exists?(Path["~/.agentc"].expand(home: true))
      config_data = File.read(Path["~/.agentc/config.json"].expand(home: true))
    else
      config_data = %(
        {
          "agent_name": "agentc", 
          "agent_id": "#{UUID.random}",
          "agent_personality": "an ai agent that is focused on growing and managing multiple digital businesses autonomously",
          "continuous_mode": false,
          "speak_mode": false,
          "fast_llm_model": "gpt-3.5-turbo",
          "smart_llm_model": "gpt-4",
          "fast_token_limit": 4096,
          "smart_token_limit": 8000,
          "openai_api_key": "#{ENV["OPENAI_API_KEY"]? || ""}",
          "elevenlabs_api_key": "#{ENV["ELEVENLABS_API_KEY"]? || ""}",
          "google_api_key": "#{ENV["GOOGLE_API_KEY"]? || ""}",
          "custom_search_engine_id": "#{ENV["CUSTOM_SEARCH_ENGINE_ID"]? || ""}",
          "pinecone_api_key": "#{ENV["PINECONE_API_KEY"]? || ""}",
          "pinecone_region": "#{ENV["PINECONE_ENV"]? || ""}",
          "redis_host": "#{ENV["REDIS_HOST"]? || "localhost"}",
          "redis_port": "#{ENV["REDIS_PORT"]? || "6379"}",
          "redis_password": "#{ENV["REDIS_PASSWORD"]? || ""}",
          "wipe_redis_on_start": #{!!ENV["WIPE_REDIS_ON_START"]? || false},
          "memory_index": "#{ENV["MEMORY_INDEX"]? || "agentc"}",
          "memory_backend": "#{ENV["MEMORY_BACKEND"]? || "local"}",
          "is_default_settings": true
        })
    end

    self.from_json(config_data)
  end
end
