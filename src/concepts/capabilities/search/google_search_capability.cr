require "../primary_capability"
require "http/client"

class GoogleSearchCapability < PrimaryCapability
  property capability_name : String = "Google Search"
  property capability_description : String = "Perform a search on Google using the Search API."

end