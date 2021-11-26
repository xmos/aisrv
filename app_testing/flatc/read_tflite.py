def modelToOpList(model_path):
  import flatbuffers
  from tflite.Model import Model

  # Update the path to your model
  model_path = model_path
  with open(model_path, "rb") as model_file:
    buffer = model_file.read()

  # Get Model
  model = Model.GetRootAs(buffer)
  # Description
  version = model.Version()
  print("Model version:", version)
  description = model.Description().decode('utf-8')
  print("Description:", description)
  subgraph_len = model.SubgraphsLength()
  print("Subgraph length:", subgraph_len)

  opsList = []
  for y in range(0, model.Subgraphs(0).OperatorsLength()):
    opcode = model.OperatorCodes(model.Subgraphs(0).Operators(y).OpcodeIndex())
    if opcode.BuiltinCode() == 32:
      opsList.append(opcode.CustomCode())
    else:
      opsList.append(opcode.BuiltinCode())
  return opsList


