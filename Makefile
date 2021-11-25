TOOLS_VERSION=15.1.3
TOOLS_PATH=/XMOS/tools/${TOOLS_VERSION}/XMOS/XTC/${TOOLS_VERSION}/
.PHONY: init
init:
	/XMOS/get_tools.py ${TOOLS_VERSION}

build:
	( \
	  cd aisrv/app_testing && \
	  source ${TOOLS_PATH}/SetEnv && \
	  xmake \
	)
