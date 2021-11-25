TOOLS_VERSION=15.1.3
TOOLS_PATH=/XMOS/tools/${TOOLS_VERSION}/XMOS/XTC/${TOOLS_VERSION}
SHELL=/bin/bash

.PHONY: init
init:
	/XMOS/get_tools.py ${TOOLS_VERSION}

.PHONY: build
build:
	( \
	  cd app_alpr && \
	  . ${TOOLS_PATH}/SetEnv && \
	  xmake \
	)
	rm -rf ../Installs/Target/aisrv
	mkdir -p ../Installs/Target/aisrv
	cp app_alpr/bin/app_alpr.xe ../Installs/Target/aisrv

.PHONY: test
test:
	echo 'Hello'
