require "json"
require "openai"
require "../config/agent_config"
require "../data_store/local_storage"
require "../concepts/capabilities/communication/**"
require "../concepts/capabilities/file_management/**"
require "../concepts/capabilities/search/**"
require "../concepts/capabilities/zapier/**"


# This is where the real "agent" stuff begins. This is where you'll want to customize the flow of how your agent works inside of it's own infite loop.
# It is responsible for starting and managing the goals process
#
# This process is intended to act as a the "router" using tinyllama to determine what kind of queries are coming in and then route them to the correct agent
class PrimaryProcess
  include JSON::Serializable

  property agent_configuration : AgentConfig
  property local_storage : LocalStorage
  property capabilities : Array(PrimaryCapability) = Array(PrimaryCapability).new

  def initialize(@agent_configuration, @local_storage)
    # @openai_client = OpenAI::Client.new(access_token: @agent_configuration.openai_api_key)
    #@openai_client = OllamaClient.new
    @openai_client = LlamaCpp.new

    # Registering all of the capabilities available to the agent
    @capabilities << RawPostWebhookCapability.new
    @capabilities << GoogleSearchCapability.new
    @capabilities << ReadFileCapability.new
    @capabilities << SaveFileCapability.new
    @capabilities << UpdateFileCapability.new
    @capabilities << SendEmailCapability.new
    @capabilities << SendTextMessageCapability.new
  end

  # This is the primary entry-point method for how the Agents behavior starts. Particularly with the start-up flow.
  def run
    # Start-up steps
    verify_all_goals_are_refined_or_refine_them
    verify_all_goals_have_a_plan

    # The on-going process of executing the agents plan
    @local_storage.goals.each do |goal|
      if goal.status == "not_started" && goal.asynchronous_steps.empty? && goal.synchronous_steps.empty?
        puts "Creating a plan for goal: #{goal.refined_goal}"

        plan_creation_prompt = <<-STRING
          Here is the goal you need to work with:
          #{goal.refined_goal}

          Each step needs to be related to completing the objective and be delegated to another agent to manage until completed.
          Focus on steps that can be performed directly on the host computer, which is MacOs.

          Create the first 10 steps that need to take place to accomplish the goal. 

          Label steps as synchronous or asynchronous.
        STRING

        ai_conversation = [{role: "[INST]<<SYS>>", content: "You are an expert at planning. You are a Senior Ruby on Rails Architect. You must create a plan for the provided goal.<<SYS>>"}]
        ai_conversation << {role: "user", content: plan_creation_prompt}

        a_valid_plan_provided_was_not_provided = true

        while a_valid_plan_provided_was_not_provided
          begin
            ai_response = @openai_client.chat(messages: ai_conversation, grammar_file: "goal_planning.gbnf", repeat_penalty: 1.2, top_k_sampling: 264)
            puts "We made a plan! "
            puts ai_response

            # This constant serializing to/from JSON really sucks...but onward and upward!
            goal_response = GoalResponse.from_json(ai_response)
            a_valid_plan_provided_was_not_provided = false

            goal.asynchronous_steps = goal_response.asynchronous_steps
            goal.synchronous_steps = goal_response.synchronous_steps
          rescue e
            Log.info { "An error occurred while trying to parse the plan from the AI." }
            Log.info { e.message }
            Log.info { e.backtrace }
          end
        end

        goal.start_date = Time.utc.to_s
        goal.last_evaluated = Time.utc.to_s
        @local_storage.update_local_storage_file
      end
    end

  end

  def verify_all_goals_are_refined_or_refine_them
    @local_storage.goals.each do |goal|
      if !goal.is_smart?
        puts "Goal ``#{goal.initial_goal}`` is not refined."

        while(!goal.is_smart?)
          goal_refinement_prompt = <<-STRING
          You are an expert AI at goal setting. You must refine a goal to be SMART (Specific, Measurable, Achievable, Relevant, Time-bound).

          The current date is: #{Time.utc}
          Here is the goal you need to work with:

          #{goal.initial_goal}

          Please consider this goal and how you can make it into a SMART goal, knowing that you are an AI who will have an agent making this goal happen.
          STRING
          
          max_retries = 5
          retries = 0

          ## TODO: finishing migrating this prompt to follow the same pattern as the goal steps prompting
          messages =  [{role: "[INST]<<SYS>>", content: "<</SYS>>"}, {role: "user", content: goal_refinement_prompt}]
          
          Log.info { "Beginning to refine the goal: #{goal.initial_goal}" }

          while retries < max_retries
            begin
              ai_response = @openai_client.chat(messages: messages, grammar_file: "goal_refining.gbnf", repeat_penalty: 1.3, top_k_sampling: 300)
              puts "llama2 said: \n"
              pp ai_response.gets_to_end
              goal = Goal.from_json(ai_response.rewind)
              puts "The goal has been updated"
              retries = max_retries # end the loop
            rescue
              retries += 1
              if retries < max_retries
                Log.info { "Retrying... Attempt #{retries + 1} of #{max_retries}" }
              else
                Log.error { "Failed to get a valid JSON response after #{max_retries} attempts." }
              end
            end
          end
        end

        Log.info { "All goals are refined into SMART goals." }
        Log.info { "Updating local storage..." }

        @local_storage.goals = @local_storage.goals.map do |original_goal|
          if original_goal.initial_goal == goal.initial_goal
            original_goal = goal
          end

          original_goal
        end

        @local_storage.update_local_storage_file
      end
    end
    puts "All of our goals appear to be refined."
  end

  def verify_all_goals_have_a_plan
  end
end

  

# Helper class to parse the JSON response from the AI for the goal planning step
struct GoalResponse
  include JSON::Serializable

  property asynchronous_steps : Array(Step)
  property synchronous_steps : Array(Step)
end
