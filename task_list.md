# Task/Feature List:

To Do:
---
[] Change the model from llama2 to Mixtril or Mistril
[] Setup a process for creating fine-tunings and lora filters
[] Improve the library so that swapping lora filters can be done on the fly and associated to a personality


Crystal Library For Llama.cpp Integration
---
[] Create a class for managing the prompt interaction with the model (decoupling from the AI client)
[] Make the AI client more easily managing the different configuration settings per model name
  [] add file caching for the prompt and model
[] Add cli commands to help download and fine-tune models