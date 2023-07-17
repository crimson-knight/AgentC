require "../primary_capability"

class UpdateFileCapability < PrimaryCapability
  property capability_name : String = "Update File"
  property capability_description : String = "Update a file that already exists on disk. If the file does not exist, it will be created."
end