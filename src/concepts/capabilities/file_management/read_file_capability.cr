require "../primary_capability"

class ReadFileCapability < PrimaryCapability
  property capability_name : String = "Read File"
  property capability_description : String = "Read from a file into memory. The file must be on the same machine as the agent. Returns the file contents as a string."


  def perform(path_to_file_to_read_from)
    # Read file as text and return it
    File.open(path_to_file_to_read_from).gets_to_end
  end

end
