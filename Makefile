TOOLS_VERSION=15.1.3
TOOLS_PATH=/XMOS/tools/${TOOLS_VERSION}/XMOS/XTC/${TOOLS_VERSION}

.PHONY: init
init:
	/XMOS/get_tools.py ${TOOLS_VERSION}

.PHONY: build
build:
	( \
	  cd aisrv/app_alpr && \
	  source ${TOOLS_PATH}/SetEnv && \
	  xmake \
	)

.PHONY: test
test:
	echo 'Hello'
