#define TFLM_OPERATORS 45
#define TFLM_RESOLVER       \
    resolver->AddSoftmax(); \
    resolver->AddPad(); \
    resolver->AddMean(); \
    resolver->AddReshape(); \
    resolver->AddConcatenation(); \
    resolver->AddFullyConnected(); \
    resolver->AddAdd(); \
    resolver->AddMaxPool2D(); \
    resolver->AddAveragePool2D(); \
    resolver->AddPad(); \
    resolver->AddLogistic(); \
    resolver->AddConv2D(); \
    resolver->AddQuantize(); \
    resolver->AddDepthwiseConv2D(); \
    resolver->AddDequantize();
#if 0
                                                                    \
    resolver->AddCustom(tflite::ops::micro::xcore::Add_8_OpCode, \
            tflite::ops::micro::xcore::Register_Add_8()); \
    resolver->AddCustom(tflite::ops::micro::xcore::MaxPool2D_OpCode, \
            tflite::ops::micro::xcore::Register_MaxPool2D()); \
    resolver->AddCustom(tflite::ops::micro::xcore::AvgPool2D_Global_OpCode, \
            tflite::ops::micro::xcore::Register_AvgPool2D_Global()); \
    resolver->AddCustom(tflite::ops::micro::xcore::AvgPool2D_OpCode, \
            tflite::ops::micro::xcore::Register_AvgPool2D()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Shallow_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Shallow()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Deep_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Deep()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_Depthwise_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_Depthwise()); \
    resolver->AddCustom(tflite::ops::micro::xcore::FullyConnected_8_OpCode, \
            tflite::ops::micro::xcore::Register_FullyConnected_8()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Conv2D_1x1_OpCode, \
            tflite::ops::micro::xcore::Register_Conv2D_1x1()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Pad_OpCode, \
            tflite::ops::micro::xcore::Register_Pad()); \
    resolver->AddCustom(tflite::ops::micro::xcore::Lookup_8_OpCode, \
            tflite::ops::micro::xcore::Register_Lookup_8());
#endif
