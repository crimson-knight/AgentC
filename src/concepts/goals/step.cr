require "json"

# This Step class is used to manage the details for Steps in a Goal. Steps are part of the overall `Plan` for a goal and this is how we track progress towards a goal.
#
# A Step has the following attributes:
# ```json
# {
#   "id": 4, // A semi-sequential ID for the step. This is from the order of creation, not the order of the steps in the plan.
#   "name": "Review and improve the blog project based on feedback",
#   "status": "not_started",
#   "preceding_steps": [3]
# }
# ```
#
class Step
  include JSON::Serializable

  property id : Int32
  property name : String
  property status : String # values must be "not_started", "in_progress", "complete", "abandoned", "blocked", "deferred"
  property preceding_steps : Array(Int32)
end