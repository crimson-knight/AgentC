require "./config/agent_config"
require "./processes/goals_process"
require "colorize"

# This GPT-Agent was inspired by Auto-GPT (written in Python)
# 
# However, this will be made available as a brew package anyone using Homebrew to install as a CLI tool
#
module AmberAgentGpt
  agent_configuration : AgentConfig
  VERSION = "0.1.0"

  # 1. Check for the configuration file in ~/.amber_agent_gpt/config.json
  agent_configuration = AgentConfig.new_from_config_file
  goals = [] of String

  puts "Welcome to Amber Agent GPT!".colorize(:red).on(:black)
  puts "This is a CLI tool to help you create your own GPT-3/GPT-4 powered agent."
  
  if agent_configuration.is_default_settings
    puts "What is your agent's name? (Leave blank for the default name)"
    user_response = gets
    agent_configuration.agent_name = user_response unless user_response.nil? || user_response.empty?

    puts "What is your agent's personality? Be descriptive and specific here."
    user_response = gets
    agent_configuration.agent_personality = user_response unless user_response.nil? || user_response.empty?
  end

  if agent_configuration.openai_api_key.empty?
    puts "We did not find an OpenAI API key in your ENV under OPENAI_API_KEY."
    puts "Please enter your OpenAI API key: "
    user_response = gets
    agent_configuration.openai_api_key = user_response unless user_response.nil? || user_response.empty?
  end

  if agent_configuration.google_api_key.empty?
    puts "We did not find a Google API Key in your ENV under GOOGLE_API_KEY."
    puts "This is required for the Google Search API to help the agents do their work."
    puts "Please enter your Google API key: "
    user_response = gets
    agent_configuration.google_api_key = user_response unless user_response.nil? || user_response.empty?
  end

  # Verify the storage option is configured properly
  case agent_configuration.memory_backend
  when .matches?(/^redis$/)
    puts "Redis is being used for the memory store."
  when .matches?(/^pinecone$/)
    puts "Using Pinecone for the memory store."

    if agent_configuration.pinecone_api_key.empty?
      puts "We did not find a Pinecone API key in your ENV under PINECONE_API_KEY."
      puts "Please enter your Pinecone API key: "
      user_response = gets
      agent_configuration.pinecone_api_key = user_response unless user_response.nil? || user_response.empty?
    end

    if agent_configuration.pinecone_region.empty?
      puts "We did not find a Pinecone region in your ENV under PINECONE_REGION."
      puts "Please enter your Pinecone region: "
      user_response = gets
      agent_configuration.pinecone_region = user_response unless user_response.nil? || user_response.empty?
    end
  else # Default to LocalStorage, which is a JSON object
    puts "LocalStorage is being used for the memory store."
    Dir.mkdir(Path["~/.amber_agent_gpt"].expand(home: true)) unless Dir.exists?(Path["~/.amber_agent_gpt"].expand(home: true))
    if File.exists?(Path["~/.amber_agent_gpt/local_storage.json"].expand(home: true))
      puts "An existing local store was found, using that going forward."
    else
      puts "Creating a new local storage file at ~/.amber_agent_gpt/local_storage.json"
      File.write(Path["~/.amber_agent_gpt/local_storage.json"].expand(home: true), "{}")
      puts "Done!"
    end
  end

  puts "Saving the configuration file before moving on..."
  agent_configuration.is_default_settings = false
  File.write(Path["~/.amber_agent_gpt/config.json"].expand(home: true), agent_configuration.to_json)

  user_input = ""
  loop do
    puts "What is your agent's goal? (Leave blank when you are finished)"
    user_input = gets
    goals << user_input unless user_input.nil? || user_input.empty?
    break if user_input.try(&.empty?)
  end

  agent_configuration.goals = goals
  puts "Alright! Let's get started!"
  # Start the goals process
  goals_process = GoalsProcess.new(agent_configuration)
  goals_process.run
end
