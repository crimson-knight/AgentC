require "../primary_capability"

class ReadFileCapability < PrimaryCapability
  property capability_name : String = "Read File"
  property capability_description : String = "Read from a file into memory. The file must be on the same machine as the agent. .txt, .csv files supported"
end
