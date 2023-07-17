require "yaml"
require "http/client"

# This is the parent class for any of the 'capabilities' of the agent. 
#
# It creates an interface and the commonly required methods for other capabilities to use for the agent to convey to the LLM of your choice.
#
# This class is NOT intended to be used directly. Inherit from it, override the default values for the following variables to get started:
#
# ```crystal
#   property capability_name
#   property capability_description
# ```
#
abstract class PrimaryCapability
  property capability_name : String = "Default"
  property capability_description : String = "Default"

  # You don't have to redefine this method, unless you want to.
  def generate_capability_description_for_goal_planning
    raise "You must initialize the `capability_description` ivar in your child class." if @capability_description.matches?(/Default/)
    raise "You must initialize the `capability_name` ivar in your child class." if @capability_name.matches?(/Default/)

    return "#{@capability_name}: #{@capability_description}\n"
  end

  # You should override this in your child class. the #perform method is expected to be defined for each capability, this is what performs the action itself.
  def perform
    raise "You need to define the #perform instance method on your child class."
  end
end
