
# Base class for all agent personalities
# 
# Every personality should inherit from here and implement the default values for these methods
class AgentPersonalityBase
  include JSON::Serializable

  property agent_name : String
  property role_description : String
  property routing_guidance : String

  property ai_client : LlamaCpp
  property capabilities : Array(PrimaryCapability)

  # Initialize the properties needed for this personality to execute on a single `Step` with default values that can easily be confirmed as "default"
  property step_to_execute : Step = Step.from_json(%({"id": 0, "name": "default", "status": "not_started", "preceding_steps": []}))
  property expected_outcome : String = ""
  property timeframe_to_complete_this_step : Time::Span = Time::Span.new(seconds: 0)
  property constraints_to_keep_in_mind : String = ""
  property additional_context_for_this_step : String = ""
  property definition_of_done_for_this_step : String = ""

  property step_to_execute_is_valid : Bool = false

  # Get the correct step details before we do anything.
  def get_the_correct_step_details_to_execute(step : Step, definition_of_done : String, timeframe_to_complete_this_step : Time::Span, constraints_to_keep_in_mind : String, additional_context_for_this_step : String) : Bool
    # Update the ivars with the details that were passed in here
    @step_to_execute = step
    @expected_outcome = expected_outcome
    @timeframe_to_complete_this_step = timeframe_to_complete_this_step
    @constraints_to_keep_in_mind = constraints_to_keep_in_mind
    @additional_context_for_this_step = additional_context_for_this_step
    @definition_of_done_for_this_step = definition_of_done

    true
  end

  # Creates the definition of done of this step, purely based on the step name and capabilities of the agent as a starting place.
  # 
  # This is intended to act as a pre-step to the execution of the step, and should be used to determine the definition of done for the step
  def determine_the_definition_of_done_for_this_step(step_name : String) : String
    prompt = <<-STRING
      Your task is to determine the definition of done for the step named #{step_name}.

      Here are the capabilities of the agent:
      #{@capabilities.join("\n")}
    STRING
    
    prompt_chain_of_messages = [
      { role: "[INST]<<SYS>>", content: "You are #{@agent_name}. #{@role_description}.<</SYS>>"}, 
      { role: "user", content: prompt }
    ]

    attempts_at_determining_the_definition_of_done = 0

    while attempts_at_determining_the_definition_of_done < 10
      unparsed_ai_response = @ai_client.chat(prompt_chain_of_messages, grammar: "generic_single_string_response.gbnf")

      begin
        parsed_ai_response = JSON.parse(unparsed_ai_response.rewind.gets_to_end)
        definition_of_done = parsed_ai_response["string"]
      rescue e
        attempts_at_determining_the_definition_of_done += 1
        Log.error { "An error occured while parsing the AI's response, trying again" }
      end
    end

    raise "Could not determine the definition of done for this step after 10 attempts" if attempts_at_determining_the_definition_of_done >= 10

    definition_of_done
  end

  # Ensure that the AI personality understands the task before it starts working
  def review_the_step_details_and_confirm_the_definition_of_done : Bool
    prompt = <<-STRING
      Your task is to first review the step details and confirm the definition of done for this step is within your capabilities.

      Here is the step you are expected to accomplish: #{@step_to_execute.name}
      Here is the definition of done for this step: #{@definition_of_done_for_this_step}
      Here is the timeframe you have to complete this step: #{@timeframe_to_complete_this_step.to_s}
      Here are any constraints you have to keep in mind: #{@constraints_to_keep_in_mind}
      Here is any additional context you have for this step: #{@additional_context_for_this_step}

      Here is a list of your capabilities:
      #{@capabilities.join("\n")}
    STRING

    prompt_chain_of_messages = [
      { role: "[INST]<<SYS>>", content: "You are #{@agent_name}. #{@role_description}.<</SYS>>"}, 
      { role: "user", content: prompt }
    ]

    is_the_definition_of_done_valid = false
    attempts_at_making_the_definition_of_done_valid = 0

    while !is_the_definition_of_done_valid && attempts_at_making_the_definition_of_done_valid < 10
      unparsed_ai_response = @ai_client.chat(prompt_chain_of_messages, grammar: "generic_bool_response.gbnf")

      begin
        parsed_ai_response = JSON.parse(unparsed_ai_response.rewind.gets_to_end)
        is_the_definition_of_done_valid = parsed_ai_response["bool"]
      rescue exception
        attempts_at_making_the_definition_of_done_valid += 1
        Log.error { "An error occured while parsing the AI's response, trying again" }
      end
    end

    raise "Could not confirm the definition of done for this step is within your capabilities after 10 attempts" if attempts_at_making_the_definition_of_done_valid >= 10

    true # The definition of done is acceptable
  end

  def execute_the_step_until_completed_or_timedout : Bool
    # Create a prompt that provides the personality in the system prompt, along with the capabilities of the agent, asking the agent to choose which capability to use and what the expected outcome is, and how to check that outcome
    
    prompt = <<-STRING
      You are working on a local Macbook Pro in the #{Dir.home} directory.

      You need to complete this step in a project: #{@step_to_execute.name}

      Here is the step you are expected to accomplish: #{@step_to_execute.name}
      Here are any constraints you have to keep in mind: #{@constraints_to_keep_in_mind}
      Here is any additional context you have for this step: #{@additional_context_for_this_step}

      Here are your capabilities to choose how you want to accomplish this step:
      #{@capabilities.join("\n")}

      Choose the capability you want to use to accomplish this step and the expected outcome of the step to verify it was successful.
    STRING

    execution_prompt_chain_of_messages = [
      { role: "[INST]<<SYS>>", content: "You are #{@agent_name}. #{@role_description}.<</SYS>>"}, 
      { role: "user", content: prompt }
    ]

    execution_attempt_counter = 0
    has_successfully_been_executed = false

    while execution_attempt_counter < 10 && !has_successfully_been_executed
      begin
        unparsed_ai_response = @ai_client.chat(execution_prompt_chain_of_messages, grammar: "using_a_capability.gbnf")
        parsed_ai_response = JSON.parse(unparsed_ai_response.rewind.gets_to_end)
        has_successfully_been_executed = parsed_ai_response["bool"]
      rescue exception
        execution_attempt_counter += 1
        Log.error { "An error occured while parsing the AI's response, trying again" }
      end
    end


    # Next, I need a parsed object that represents the chosen capability and the expected outcome of the step to verify it was successful
    # Then I need to execute or perform the capability, collect the results and verify with the AI that this is the expected outcome

    
    true # Always return true for now, we'll return `false` if we timeout or can't figure out how to accomplish what we are currently doing
  end

  # Perform the chosen capability, collect the results and verify with the AI that this is the expected outcome
  def perform_the_chosen_capability_and_verify_the_expected_outcome : Bool
    # TODO: Implement this method
    # 
    # 
    true
  end
end
