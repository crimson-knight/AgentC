require "./ai_clients/*"
require "./config/agent_config"
require "./data_store/local_storage"
require "./concepts/goals/goal"
require "./processes/primary_process"
require "colorize"
require "log"

# This ChatGPT-Agent was inspired by Auto-GPT (written in Python).
#
# However, this agent is designed entirely different.
#
# Auto-GPT is designed to be a single agent that can do anything. But due to the limitations for how long-term memory works and the constraints on tokens for every request, it makes the agents very prone to go off track and waste time.
# So instead of trying to achieve AGI using a single LLM with a small token size per request, this is is going to be more focused.
# The agent will take a goal, and then it will use the GPT-3/GPT-4 API to refine that goal into a SMART goal.
# It will then use the SMART goal to create a plan of action based on it's known capabilities, and then it will execute that plan of action.
# The agent will then use the results of the plan of action to update it's long-term memory with the plan and track the status of that plan as it progresses.
#
# This agent type is designed to be run from the command line, but not as a daemon. It will be run as a daemon in the future, which is how it'll handle scheduled tasks without requiring the CLI tool be running in a window.
# 
module AgentC
  agent_configuration : AgentConfig = AgentConfig.create_new_config_file_or_load_existing_config
  local_storage : LocalStorage = LocalStorage.get_default_local_storage_or_custom_local_storage_location(agent_configuration.custom_local_storage_path)
  VERSION = "0.1.0" # Yeah, it's still Alpha.

  puts "Welcome to AgentC!".colorize(:red).on(:black)
  puts "This is a CLI tool to help you create your own GPT-3.5/GPT-4 (assuming you have API access for v4) powered agent."
  
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
  ## TODO: Add a client for Redis and Pinecone as a storage option. For now, we'll just use LocalStorage.
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
    Dir.mkdir(Path["~/.agentc"].expand(home: true)) unless Dir.exists?(Path["~/.agentc"].expand(home: true))
    if File.exists?(Path["~/.agentc/local_storage.json"].expand(home: true))
      puts "An existing local store was found, using that going forward."
    else
      puts "Creating a new local storage file at ~/.agentc/local_storage.json"
      File.write(Path["~/.agentc/local_storage.json"].expand(home: true), "{}")
      puts "Done!"
    end
  end

  puts "Saving the configuration file before moving on..."
  agent_configuration.is_default_settings = false
  File.write(Path["~/.agentc/config.json"].expand(home: true), agent_configuration.to_json)

  # 1. IF local storage does not have any goals
  #     Ask the user for their agent's goals
  #     Save the goals to the local storage, unrefined
  # 2. ELSE
  #     Show the goals that were found in local storage
  #     TODO: Prompt the user to add more goals or remove goals
  if local_storage.goals.empty?
    goals = [] of Goal
    self.prompt_for_additional_goals(goals)
    agent_configuration.goals = goals
    local_storage.goals = goals
  else
    puts "The following goals were found in your local storage: "
    local_storage.goals.each do |goal|
      puts "Original Goal: #{goal.initial_goal}\nGoal status: #{goal.status}\nRefined Goal: #{goal.refined_goal}\nGoal start date: #{goal.start_date}"
    end

    puts "Would you like to add more goals? (yes/no)"
    user_input = gets
    self.prompt_for_additional_goals(local_storage.goals) if user_input.try &.downcase == "yes"
  end

  
  Log.info { "Starting the primary process..." }
  # Start the goals process
  goals_process = PrimaryProcess.new(agent_configuration: agent_configuration, local_storage: local_storage)
  goals_process.run

  def self.prompt_for_additional_goals(existing_goals_array : Array(Goal))
    user_input = ""
    loop do
      puts "What are your agents goals? (Leave blank when you are finished)"
      user_input = gets
      existing_goals_array << Goal.from_json(%({"initial_goal": "#{user_input}"})) unless user_input.nil? || user_input.empty?
      break if user_input.try(&.empty?)
    end
    return existing_goals_array
  end
  
end
