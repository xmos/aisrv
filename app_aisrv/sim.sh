xsim --plugin LoopbackPort.so \
       '-port tile[0] XS1_PORT_1A 1 0 -port tile[0] XS1_PORT_1C 1 0
        -port tile[0] XS1_PORT_1B 1 0 -port tile[0] XS1_PORT_1D 1 0
        -port tile[0] XS1_PORT_4A 4 0 -port tile[0] XS1_PORT_4B 4 0
        -port tile[0] XS1_PORT_1E 1 0 -port tile[0] XS1_PORT_1I 1 0
        -port tile[0] XS1_PORT_1F 1 0 -port tile[0] XS1_PORT_1J 1 0
        -port tile[0] XS1_PORT_1G 1 0 -port tile[0] XS1_PORT_1K 1 0
        -port tile[0] XS1_PORT_1H 1 0 -port tile[0] XS1_PORT_1L 1 0
       ' \
     --vcd-tracing '-o blah.vcd -pads -tile tile[0] -ports'  \
     $* bin/test.xe
