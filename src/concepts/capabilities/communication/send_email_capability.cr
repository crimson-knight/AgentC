require "../primary_capability"

class SendEmailCapability < PrimaryCapability
  property capability_name : String = "Send Email"
  property capability_description : String = "Send an email to the agent manager."
end
