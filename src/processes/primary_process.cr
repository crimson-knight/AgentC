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
class PrimaryProcess
  include JSON::Serializable

  property agent_configuration : AgentConfig
  property local_storage : LocalStorage
  property capabilities : Array(PrimaryCapability) = Array(PrimaryCapability).new

  def initialize(@agent_configuration, @local_storage)
    # @openai_client = OpenAI::Client.new(access_token: @agent_configuration.openai_api_key)
    @openai_client = OllamaClient.new

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
          You are an expert AI at planning for goals. You must create a plan for a goal using the knowledge of your agent capabilities.

          Here is the goal you need to work with:
          #{goal.refined_goal}

          Here are the capabilities you have available to you:
          #{@capabilities.each { |capability| capability.generate_capability_description_for_goal_planning}}

          Each step needs to be related to completing the objective and be delegated to another agent to manage until completed.
          Focus on steps that can be performed directly on the host computer, which is MacOs.


          You must respond with your plan for this goal using the following JSON format, using 100% valid JSON:

          ```json
          {
            "asynchronous_steps": [
              {
                "id": 1,
                "name": "Research and enroll in a suitable online Python course",
                "status": "not_started",
                "preceding_steps": []
              },
              {
                "id": 2,
                "name": "Dedicate 5 hours per week to learning Python",
                "status": "not_started",
                "preceding_steps": [1]
              }
            ],
            "synchronous_steps": [
              {
                "id": 3,
                "name": "Apply the learned concepts by building a small blog project",
                "status": "not_started",
                "preceding_steps": [1, 2]
              },
              {
                "id": 4,
                "name": "Review and improve the blog project based on feedback",
                "status": "not_started",
                "preceding_steps": [3]
              }
            ]
          }
          ```

          Definitions: 
          synchronous_steps can be performed in parallel and do not depend on any other synchronous step being completed first. Synchronous steps can depend on asynchronous_steps being completed first.
          Asynchronous_steps must be completed in order and cannot be performed in parallel. Asynchronous steps can be performed in parallel with synchronous steps.
        STRING
        
        ai_response = @openai_client.chat(messages: [{role: "user", content: plan_creation_prompt}])
        puts "We made a plan! "
        puts ai_response["message"]["content"]

        # Need to parse these steps into the goal object

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

          Here is the format your response must be in. Update the necessary fields based on how you refine your goal. Your response must be entirely valid JSON.
          {
            "specific": false,
            "initial_goal": "#{goal.initial_goal}",
            "refined_goal": "<< insert your refined goal text here >>",
            "measurable": false,
            "achievable": false,
            "relevant": false,
            "time_bound": false,
            "deadline": "2023-08-14",
            "start_date": "2023-05-14",
            "status": "not_started",
            "repeatable": false,
            "repeat_attributes": ["start_date"],
            "evaluation_frequency": "weekly",
            "last_evaluation": null,
            "adjustments": [],
            "asynchronous_steps": [],
            "synchronous_steps": []
          }

          Make sure to set a startdate, and evaluation frequency. The start date should always be right away, unless a start time was originally provided or if the goal is contingent on another goals completion. You can set an end-date non-repeating goals. Set "repeatable" to `true` if it should be repeated.
          "status" should always be "not_started" for new goals. "repeat_attributes" should be an array of attributes that should be repeated.
          "evaluation_frequency" can be: "daily", "weekly", "semi-weekly", "monthly", "semi-monthly", "quarterly", "yearly
          ignore the "adjustments", "synchronous_steps" and "asynchronous_steps" fields for now.
          Your entire response must be valid JSON so that it can be directly parsed by the agent.
          STRING
          
          max_retries = 5
          retries = 0
          messages =  [{role: "user", content: goal_refinement_prompt}]
          ai_response = @openai_client.chat(messages: messages)

          while retries < max_retries
            begin
              
              extracted_json = @openai_client.chat(messages: [{role: "user", content: "extract and return the JSON from the follow prompt response: \n#{ai_response["message"]["content"]}"}], model: "codellama:7b")
              puts "llama2 said: \n"
              pp ai_response["message"]["content"]
              puts "\n\n extracted json response:\n"
              pp extracted_json["message"]["content"]
              goal = Goal.from_json(extracted_json["message"]["content"].as_s)
              puts "The goal has been updated"
              retries = max_retries # end the loop
            rescue
              puts "Received an invalid JSON response from the AI."
              retries += 1
              if retries < max_retries
                # turn this into a log instead of terminal output
                puts "Retrying... Attempt #{retries + 1} of #{max_retries}"
                # Optionally, send feedback to AI for correction before retrying
                messages << {role: "assistant", content: ai_response.not_nil!["message"]["content"].as_s}
                messages << {role: "user", content: "Please correct your response to be perfectly valid JSON only"}
              else
                puts "Failed to get a valid JSON response after #{max_retries} attempts."
              end
            end
          end
        end

        puts "All goals are refined into SMART goals."
        puts "Updating local storage..."
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

  ## Kept this for easy reference only. Do not use.
  def old_run_do_not_use
    prompt_text = <<-STRING
      Here are your goals:
      #{@agent_configuration.goals.join("\n")}
    
      Your decisions must always be made independently without seeking user assistance. Play to your strengths as an LLM and pursue simple strategies with no legal complications.
      
      CONSTRAINTS:
      1. ~4000 word limit for short term memory. Your short term memory is short, so immediately save important information to files.
      2. If you are unsure how you previously did something or want to recall past events, thinking about similar events will help you remember.
      3. No user assistance
      4. Exclusively use the commands listed in double quotes e.g. "command name"

      COMMANDS:
      1. Google Search: "google", args: "input": "<search>"
      5. Browse Website: "browse_website", args: "url": "<url>", "question": "<what_you_want_to_find_on_website>"
      6. Start GPT Agent: "start_agent",  args: "name": "<name>", "task": "<short_task_desc>", "prompt": "<prompt>"
      7. Message GPT Agent: "message_agent", args: "key": "<key>", "message": "<message>"
      8. List GPT Agents: "list_agents", args: ""
      9. Delete GPT Agent: "delete_agent", args: "key": "<key>"
      10. Write to file: "write_to_file", args: "file": "<file>", "text": "<text>"
      11. Read file: "read_file", args: "file": "<file>"
      12. Append to file: "append_to_file", args: "file": "<file>", "text": "<text>"
      13. Delete file: "delete_file", args: "file": "<file>"
      14. Search Files: "search_files", args: "directory": "<directory>"
      15. Evaluate Code: "evaluate_code", args: "code": "<full_code_string>"
      16. Get Improved Code: "improve_code", args: "suggestions": "<list_of_suggestions>", "code": "<full_code_string>"
      17. Write Tests: "write_tests", args: "code": "<full_code_string>", "focus": "<list_of_focus_areas>"
      18. Execute Python File: "execute_python_file", args: "file": "<file>"
      19. Task Complete (Shutdown): "task_complete", args: "reason": "<reason>"
      20. Generate Image: "generate_image", args: "prompt": "<prompt>"
      21. Do Nothing: "do_nothing", args: ""

      RESOURCES:
      1. Internet access for searches and information gathering.
      2. Long Term memory management.
      3. GPT-3.5 powered Agents for delegation of simple tasks.
      4. File output.

      PERFORMANCE EVALUATION:
      1. Continuously review and analyze your actions to ensure you are performing to the best of your abilities.
      2. Constructively self-criticize your big-picture behavior constantly.
      3. Reflect on past decisions and strategies to refine your approach.
      4. Every command has a cost, so be smart and efficient. Aim to complete tasks in the least number of steps.

      You should only respond in JSON format as described below

      RESPONSE FORMAT:
      {
          "thoughts":
          {
              "text": "thought",
              "reasoning": "reasoning",
              "plan": "- short bulleted\n- list that conveys\n- long-term plan",
              "criticism": "constructive self-criticism",
              "speak": "thoughts summary to say to user"
          },
          "command": {
              "name": "command name",
              "args":{
                  "arg name": "value"
              }
          }
      }
    STRING

    pp @openai_client.chat("gpt-3.5-turbo", [{role: "user", content: prompt_text}])
  end
end