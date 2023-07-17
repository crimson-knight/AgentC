require "../primary_capability"

# 
# This class defines the default behavior for the Zapier webhooks that the agent can publish TO.
# 
#
class RawPostWebhookCapability < PrimaryCapability
  property capability_name : String = "Zapier webhooks"
  property capability_description : String = "Publish to a series of Zapier webhooks that can do various simple tasks."
  property collection_of_webhooks : Array(Hash(Symbol, String)) = [] of Hash(Symbol, String)

  # This is the initializer for the ZapierWebHooksCapability class.
  #
  # Register each capability inside of this initializer.
  # 
  # Each Hash(Symbol, String) needs to have the following:
  #   :name - the name of the webhook process
  #   :description - a description of what the webhook does
  #   :url - the URL of the webhook
  #   :method - the HTTP method to use (GET, POST, PUT)
  #   :body - language explanation of what the body should be for the LLM to provide
  def initialize
    collection_of_webhooks << {
      :name => "Goal Planning", 
      :description => "Publishes to a webhook that will create a new goal in the goal planning app.", 
      :url => "https://hooks.zapier.com/hooks/catch/123456/abcdef/", 
      :method => "POST", 
      :body => "The body should be a JSON object with the following keys: 'goal_name', 'goal_description', 'goal_due_date', 'goal_priority', 'goal_category', 'goal_tags', 'goal_notes'"
    }
  end

  # Generates the general capability of the known Zapier webhooks.
  def generate_capability_description_for_goal_planning
    all_zapier_webhook_capabilities = [] of String
    collection_of_webhooks.each do |webhook|
      all_zapier_webhook_capabilities << "#{webhook[:name].try(&.to_s)}: #{webhook[:description]}\n"
    end
  end

end
