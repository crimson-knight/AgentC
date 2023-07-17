require "../primary_capability"
require "http/client"

class SendTextMessageCapability < PrimaryCapability
  property capability_name : String = "Send Text Message"
  property capability_description : String = "Send a text message to the agent manager to get user input"
end