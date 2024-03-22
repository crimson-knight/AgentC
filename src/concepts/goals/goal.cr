require "json"
require "./step"


# This object encapsulates the idea of a "goal", and that's it. Individual goals are stored as valid JSON that looks similar to this:
#
# ```json
# {
#   "specific": true,
#   "initial_goal": "Learn Python programming",
#   "refined_goal": "Learn Python programming in order to build a small blog project",
#   "measurable": true,
#   "achievable": true,
#   "relevant": true,
#   "time_bound": true,
#   "deadline": "2023-08-14",
#   "start_date": "2023-05-14",
#   "status": "not_started",
#   "repeatable": true,
#   "repeat_attributes": ["start_date", "deadline"],
#   "evaluation_frequency": "weekly",
#   "last_evaluation": null,
#   "adjustments": [],
#   "assigned_agent": "",
#   "asynchronous_steps": [
#     {
#       "id": 1,
#       "name": "Research and enroll in a suitable online Python course",
#       "status": "not_started",
#       "preceding_steps": []
#     },
#     {
#       "id": 2,
#       "name": "Dedicate 5 hours per week to learning Python",
#       "status": "not_started",
#       "preceding_steps": [1]
#     }
#   ],
#   "synchronous_steps": [
#     {
#       "id": 3,
#       "name": "Apply the learned concepts by building a small blog project",
#       "status": "not_started",
#       "preceding_steps": [1, 2]
#     },
#     {
#       "id": 4,
#       "name": "Review and improve the blog project based on feedback",
#       "status": "not_started",
#       "preceding_steps": [3]
#     }
#   ]
# }
# ```
class Goal
  include JSON::Serializable

  property initial_goal : String = ""
  property refined_goal : String = ""
  property specific : Bool = false        # S
  property measurable : Bool = false      # M
  property achievable : Bool = false      # A
  property relevant : Bool = false        # R
  property time_bound : Bool = false      # T
  property deadline : String = ""
  property start_date : String = ""
  property status : String = "not_started" # Valid values are: "Not started", "In progress", "Completed - Successful", "Completed - Unsuccessful", "On hold", "Cancelled
  property repeatable : Bool = false
  property repeat_updates : Array(String) = [] of String
  property evaluation_frequency : String = "Daily" # Valid values are: "Daily", "Weekly", "Bi-Monthly", "Monthly", "Quarterly", "Yearly"
  property adjustments : Array(String) = [] of String
  property last_evaluated : String = ""
  property asynchronous_steps : Array(Step) = [] of Step
  property synchronous_steps : Array(Step) = [] of Step
  property assigned_agent : String = "" # Blank name for the default agent

  def is_smart?
    specific && measurable && achievable && relevant && time_bound
  end
end
  