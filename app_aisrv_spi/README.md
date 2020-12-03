app_aisrv
=========

(slightly messy) build instructions
-----------------------------------

- ensure XMOS tools are setup
- clone the aisrv repo with submodules (git clone --recursive git@github0.xmos.com:xmos-int/aisrv.git)
   - This should also clone ai_tools
- cd aisrv/app_aissrv_spi
- source Setenv.sh
   - sets XMOS_AITOOLS_PATH to point to ai_tools
- mkdir build
- cd build
- cmake ../
- xmake

Running
-------

- Run xcore program: 
    - xrun --io --xscope aisrv_spi.xe
- Run master on PSOC
    - To be documented.



