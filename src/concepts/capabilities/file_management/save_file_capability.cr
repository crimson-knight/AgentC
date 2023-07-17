require "../primary_capability"

class SaveFileCapability < PrimaryCapability
  property capability_name : String = "Save File"
  property capability_description : String = "Save a new file to the local drive. If the file already exists, it will be saved over entirely."
end
