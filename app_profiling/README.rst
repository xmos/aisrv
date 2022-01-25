app_profiling: Precision Profiling App
=======================================

Dependencies
--------------------

XMOS Tools must be installed to a recent version, and the SetEnv.sh command
run in the terminal.

Then use::
  
  xmake init

This will upgrade pip, and install the required modules.

Building/Running Profiling
--------------------------

Each of the two binaries can be build seperately using "xmake si", and "xmake pi".
Where si means that the secondary memory is internal (and primary is external),
and pi means that primary memory is internal (and secondary external).

These two binaries will be built automatically when the "xmake profile" command
is run, and the models in the ./profiling/config.yaml file will be profiled.

The profiling results for each model are generated in the ./profiling/results
directory