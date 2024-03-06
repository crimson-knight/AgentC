
# The primary client for interacting directly with models that are available on the local computer.
# 
# This class allows the app to switch out specific fune-tuning aspects that improve the models accuracy for specific tasks. This includes:
#   - adding custom `grammars` for customizing response formats
#   - adding or switching out LoRA's
#   - managing the model's context window (token length)
#
# Logs are always disabled with --log-disable when running from within this app
class LlamaCpp

  property model_name : String = "llama-2-13b-chat.Q6_K.gguf"
  property grammar_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/grammars"]
  property lora_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/loras"]
  property model_root_path : Path = Path["/Users/#{`whoami`.strip}/.agentc/models"]

  # Adjust up to punish repetitions more harshly, lower for more monotonous responses. Default: 1.1
  property repeat_pentalty : Float32 = 1.1 # --repeat-penalty

  # Adjust up to get more unique responses, adjust down to get more "probable" responses. Default: 40
  property top_k_sampling : Int32 = 40 # --top-k

  # Number of threads. Should be set to the number of physical cores, not logical cores. The M1 Max has a 10 core CPU and 32 core GPU. Let's try it with 32 to start
  property threads : Int32 = 32 # --threads

  # This is just the name of the grammer file, relative to the grammar_root_path. If it's blank, it's not included in the execute command
  property grammer_file : String = "" # --grammer-file

  # Defaults are too small in the model binary (512) so setting this to 2048, which is what Llama models were trained using.
  property context_size : Int32 = 2048 # --ctx-size

  # Adjust up or down to play with creativity
  property temperature : Float32 = 0.9 # --temperature

  # Include this to make parsing system responses easier. It acts like an opening HTML tag, but there's no closing component
  property in_suffix : String = "<Assistant: " # --in-suffix

  # This is just a good idea, it helps keep the original prompt in the context window. This should keep the model more focused on the original topic.
  property keep : String = "--keep"

  # Setting this changes how many tokens are trying to be predicted at a time. Setting this to -1 will generate tokens infinitely, but causes the context window to reset frequently.
  # Setting this to -2 stops generating as soon as the context window fills up
  property n_predict : Int32 = 256


  def chat(messages : Array(NamedTuple(role: String, content: String)), model : String = model_name, temperature : Float32 = @temperature, max_tokens : Int32 = @context_size, grammar_file = "", repeat_penalty = @repeat_pentalty, top_k_sampling = @top_k_sampling, n_predict = @n_predict)
    if grammar_file.blank?
      grammar_file_command = ""
    else
      grammar_file_command = "--grammar-file \"#{@grammar_root_path.join(grammar_file)}\""
    end

    if @in_suffix.blank?
      in_suffix_command = ""
    else
      in_suffix_command = "--in-suffix \"#{@in_suffix}\""
    end

    prompt_text = ""

    # Change this into a prompting format that more clearly uses the User/Assistant format. Need to look it up in the docs though!
    messages.each { |message| prompt_text += message["role"] + ": " + message["content"] + "\n" }

    response_json = Hash(String, Hash(String, String)).new
    content = Hash(String,String).new
    current_bot_process_output = ""

    query_count = 0
    successfully_completed_chat_completion = false

    process_id_channel = Channel(Int64).new(capacity: 1)
    process_output_channel = Channel(IO).new(capacity: 1)
    query_count_incrementer_channel = Channel(Int32).new(capacity: 1)
    successfully_completed_chat_completion_channel = Channel(Bool).new(capacity: 1)

    while query_count < 5
      break if successfully_completed_chat_completion
      puts "Query count... #{query_count}"

      spawn do
        puts "spawning a fiber for the process..."
        begin
          puts "running the process"
          current_process = Process.new("llamacpp -m \"#{model_root_path.join(model_name)}\" #{grammar_file_command} --n-predict #{n_predict} --threads #{@threads} --ctx-size #{max_tokens} --temp #{temperature} --top-k #{top_k_sampling} --repeat-penalty #{repeat_penalty} --log-disable --prompt \"#{prompt_text}\"", shell: true, input: Process::Redirect::Close, output: Process::Redirect::Pipe, error: Process::Redirect::Close)
          puts "sending the pid"
          process_id_channel.send(current_process.pid)
          process_output_channel.send(current_process.output)
          current_process.wait

          puts "The llm process was finished! This should _not_ loop now"
          
          successfully_completed_chat_completion_channel.send(true)
          query_count_incrementer_channel.send(5)
        rescue e
          puts "error was rescued while trying to query the llm"
          puts e
          query_count_incrementer_channel.send(1)
          content["content"] = "error was rescued while trying to query the llm"
        end
      end
      
      puts "A fiber has spawned... now waiting for a response before timing out"
      
      # Multi-threaded keyword here, this acts like a blocking mechanism to allow for reflecting on the previously spawned fiber
      select
      # When the process outputs something, capture it and send it to the content hash
      when content_io = process_output_channel.receive
        puts "The process has output something and been recieved back into the main fiber"
        content["content"] = content_io.gets_to_end
        
        
      when timeout(2.minute)
        puts "timed out, checking the process status..."
        
        if Process.exists?(process_id_channel.receive)
          puts "The process is still running, let's wait for the output channel to receive something"
          sleep 30.seconds
          puts "checking the process output again..."
          output = process_output_channel.receive
          content["content"] = output.gets_to_end
          
          puts "The process has outputted something, let's check it out"
          puts content["content"]
        end
        
        # If the pid for the process is still running, check the last output for this process and compare it to the last known output. If it's the same, kill the process and move on
        if content["content"].empty?
          content["content"] = %({ "error": "5 attempts were made to generate a chat completion and timed out every time. Try changing your prompt." })
        end
        
        query_count += 1
      end

      successfully_completed_chat_completion = successfully_completed_chat_completion_channel.receive
    end

    process_id_channel.close
    process_output_channel.close
    query_count_incrementer_channel.close
    successfully_completed_chat_completion_channel.close
    
    response_json["message"] = content
    return JSON.parse(response_json.to_json)
  end
end

