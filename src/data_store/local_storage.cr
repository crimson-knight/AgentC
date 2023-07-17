require "json"
require "../concepts/goals/goal"

class LocalStorage
  include JSON::Serializable

  property goals : Array(Goal) = [] of Goal
  #property schedule : Array(Schedule) = [] of Schedule


  # Update the local store file with whatever it's current state is. 
  def update_local_storage_file
    File.write(Path["~/.agentc/local_storage.json"].expand(home: true), self.to_json)
  end

  # Read your goals from a local storage file.
  # 
  # Allows you to configure a different path to the local storage file. Must be configured from the agent-config.json file.
  def self.get_default_local_storage_or_custom_local_storage_location(optional_local_storage_alternative_path : String = "")
    if optional_local_storage_alternative_path.empty? 
      LocalStorage.from_json(File.read(Path["~/.agentc/local_storage.json"].expand(home: true)))
    else
      LocalStorage.from_json(optional_local_storage_alternative_path)
    end
  end
end