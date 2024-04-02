require "json"
require "openai"
require "../config/agent_config"
require "../data_store/local_storage"
require "../concepts/capabilities/communication/**"
require "../concepts/capabilities/file_management/**"
require "../concepts/capabilities/search/**"
require "../concepts/capabilities/zapier/**"
require "../concepts/agent_personalities/**"


# This is where the real "agent" stuff begins. This is where you'll want to customize the flow of how your agent works inside of it's own infite loop.
# It is responsible for starting and managing the goals process
#
# This process is intended to act as a the "router" using tinyllama to determine what kind of queries are coming in and then route them to the correct agent
class PrimaryProcess
  include JSON::Serializable

  property agent_configuration : AgentConfig
  property local_storage : LocalStorage
  property capabilities : Array(PrimaryCapability) = Array(PrimaryCapability).new
  property agent_personalities : Array(AgentPersonalityBase) = Array(AgentPersonalityBase).new

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

    # Registering all of the agent personalities available to choose from
    @agent_personalities << ArchitectAxiom.new(capabilities: @capabilities, ai_client: @openai_client)
    @agent_personalities << IntegratorIan.new(capabilities: @capabilities, ai_client: @openai_client)
    @agent_personalities << ProductOwner.new(capabilities: @capabilities, ai_client: @openai_client)
    @agent_personalities << QATronix.new(capabilities: @capabilities, ai_client: @openai_client)
    @agent_personalities << RubyDeveloperDelta.new(capabilities: @capabilities, ai_client: @openai_client)
    @agent_personalities << SecuritySentinalSigma.new(capabilities: @capabilities, ai_client: @openai_client)
  end

  # This is the primary entry-point method for how the Agents behavior starts. Particularly with the start-up flow.
  def run
    # Start-up steps
    verify_all_goals_are_refined_or_refine_them
    verify_all_goals_have_a_plan

    # The on-going process of executing the agents plan
    # 
    # 1. Loop through all of the goals and begin executing the plan
    #   a. If the goal has not been assigned to an Agent personality yet, prompt the AI to assign it to an Agent personality
    #   b. If the goal has been assigned to an Agent personality, find the current step and begin working
    # 2. TODO If there are no steps that can be worked on right away, wait and periodically check for any scheduled tasks to work on
    
    # Performs Step 1. and loops through all of the goals, but it just begins working on the first step that needs to be executed
    work_on_next_available_step
  end

  # This will use the AI to review the goal and refine it into a SMART goal.
  #
  # TODO: This should be refactored so that the AI can get feedback from the user so it's actually a realistic goal
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
            puts "Max retries: #{max_retries}"
            puts "Retry count: #{retries}"
            begin
              ai_response = @openai_client.chat(messages: messages, grammar_file: "goal_refining.gbnf", repeat_penalty: 1.1, top_k_sampling: 284)
              puts "llama2 said: \n"
              puts ai_response.gets_to_end
              
              # Update the existing goal with the refined goal details that make the goal SMART
              tmp_goal = Goal.from_json(ai_response.rewind)
              goal.specific = tmp_goal.specific
              goal.measurable = tmp_goal.measurable
              goal.achievable = tmp_goal.achievable
              goal.relevant = tmp_goal.relevant
              goal.time_bound = tmp_goal.time_bound
              goal.refined_goal = tmp_goal.refined_goal

              Log.info { "The goal has been successfully refined." }
              retries = max_retries # end the loop
              puts "Retries: #{retries}"
            rescue e
              Log.error { "An error occurred while trying to parse the refined goal from the AI." }

              retries += 1
              if retries < max_retries
                Log.info { "Retrying... Attempt #{retries + 1} of #{max_retries}" }
              else
                Log.error { "Failed to get a valid JSON response after #{max_retries} attempts." }
              end
            end

            puts "Retries at the end of the loop: #{retries}"
          end
        end

        Log.info { "All goals are refined into SMART goals." }
        Log.info { "Updating local storage..." }

        @local_storage.update_local_storage_file
      end
    end
    puts "All of our goals appear to be refined."
  end

  # Loop through every goal, if a plan does not already exist create a new one
  def verify_all_goals_have_a_plan
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

          You must create a plan for the provided goal by creating a list of steps.
        STRING

        ai_conversation = [{role: "[INST]<<SYS>>", content: "You are an expert at planning. You are a Senior Ruby on Rails Architect. You must create a plan for the provided goal.<<SYS>>"}]
        ai_conversation << {role: "user", content: plan_creation_prompt}

        a_valid_plan_provided_was_not_provided = true

        while a_valid_plan_provided_was_not_provided
          begin
            ai_response = @openai_client.chat(messages: ai_conversation, grammar_file: "goal_planning.gbnf", repeat_penalty: 1.2, top_k_sampling: 64)
            puts "We made a plan! "
            puts ai_response

            # Parse the response here, it may fail, hence the rescue here to auto retry
            goal_response = GoalResponse.from_json(ai_response)

            if goal_response.asynchronous_steps.any? || goal_response.synchronous_steps.any?
              a_valid_plan_provided_was_not_provided = false
              goal.asynchronous_steps = goal_response.asynchronous_steps
              goal.synchronous_steps = goal_response.synchronous_steps
            end
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

  # This begins working through all of the goals to determine what to work on next. It'll start working on the first thing it comes across that can be worked on.
  # TODO: turn this step into more of a prioritization step so we can balance working on things that are taking time and being punctual with performing scheduled tasks that long running work may collide with.
  def work_on_next_available_step
    @local_storage.goals.each do |goal|

      # Determine if any steps have been started, if not, start the first step
      if goal.status == "not_started" || goal.status == "in_progress"

        # We are starting with synchronous steps only
        if goal.synchronous_steps.any?
          next_step = goal.synchronous_steps.find { |step| step.status == "not_started" } || Step.from_json(%({ "id": -1, "name": "Start the goal", "status": "not_started", "preceding_steps": [] }))
          
          raise "The next step is not valid." if next_step.id == -1
          
          if next_step.status == "not_started"
            next_step.status = "in_progress"
            goal.start_date = Time.utc.to_s
            goal.last_evaluated = Time.utc.to_s
          end

          Log.info { "Determining which agent is assigned to this agent: #{goal.assigned_agent}"}

          goal.assigned_agent = determine_which_agent_to_assign_to_the_step(goal.refined_goal, next_step.name)
          # We now have the agent assigned to the next task to start working on. Now what?

        end
      end
    end
  end

  private def determine_which_agent_to_assign_to_the_step(goal_text, step_name) : String
    # Create a prompt that includes all of the known personalities and let's the AI choose which personality to assign to the current step
    prompt = <<-STRING
      From the following list of role names and personalities, select the most correct agent to assign to the next step.
      Here is the next step in the process that this agent will be responsible for: #{step_name}
      #{@agent_personalities.map { |personality| "- #{personality.agent_name}: #{personality.routing_guidance}" }.join("\n")}
    STRING 
    
    # [INST] Instruction tag closure happens in the LlamaCpp class
    messages = [{role: "[INST]<<SYS>>", content: "You are an assistant AI who is responsible for assigning the correct agent to the next step in the goal.<</SYS>>"}, {role: "user", content: prompt}]

    a_valid_plan_provided_was_not_provided = false
    while !a_valid_plan_provided_was_not_provided
      ai_response = @openai_client.chat(messages: messages, grammar_file: "agent_assignment.gbnf", repeat_penalty: 1.2, top_k_sampling: 64)
      puts ai_response.gets_to_end
      begin
        parsed_response = JSON.parse(ai_response.rewind.gets_to_end)
        a_valid_plan_provided_was_not_provided = true
      rescue e
        Log.error { "An error occurred while trying to parse the assigned agent from the AI. Retrying" }
      end
    end

    raise "The AI did not provide a valid response for the assigned agent." if parsed_response.nil?
    return parsed_response["agent_personality"].as_s
  end
end
  

# Helper struct to parse the JSON response from the AI for the goal planning step.
# This only serves to parse the JSON response from the AI for the goal planning step.
struct GoalResponse
  include JSON::Serializable

  property asynchronous_steps : Array(Step)
  property synchronous_steps : Array(Step)
end
