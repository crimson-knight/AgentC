
# Base class for all agent personalities
# 
# Every personality should inherit from here and implement the default values for these methods
class AgentPersonalityBase
  include JSON::Serializable

  property agent_name : String
  property role_description : String
  property routing_guidance : String

end