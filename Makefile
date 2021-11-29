TOOLS_VERSION=15.1.3
TOOLS_PATH=/XMOS/tools/${TOOLS_VERSION}/XMOS/XTC/${TOOLS_VERSION}
SHELL=/bin/bash

.PHONY: init
init:
	/XMOS/get_tools.py ${TOOLS_VERSION}

.PHONY: build
build:
	( \
	  cd app_regression_si && \
	  . ${TOOLS_PATH}/SetEnv.sh && \
	  xmake \
	)
	( \
	  cd app_regression_pi && \
	  . ${TOOLS_PATH}/SetEnv.sh && \
	  xmake \
	)
	rm -rf ../Installs/Target/aisrv
	mkdir -p ../Installs/Target/aisrv
	cp app_regression_si/bin/app_regression_si.xe ../Installs/Target/aisrv
	cp app_regression_pi/bin/app_regression_pi.xe ../Installs/Target/aisrv
.PHONY: test
test:
	echo 'Hello'

.PHONY: artifacts
artifacts:
	mkdir -p $(OUTPUT)
	cp  ../Installs/Target/aisrv/* $(OUTPUT)