require "json"

# This is the primary agent, your "Top" agent that manages the overall process for what is trying to be accomplished
class PrimaryAgent
  include JSON::Serializable

  property agent_name : String
  property agent_id : String
  property agent_personality : String
  property goals : Array(String)
  #property delegated_agents : Array(DelegatedAgent) = [] of DelegatedAgent

  def assess_progress_toward_goals

  end
end
