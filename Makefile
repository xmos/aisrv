.PHONY: init
init:
	git submodule update --init --recursive --depth=1

build:
	(
	  cd aisrv/app_testing && \
	  source /XMOS/tools/$TOOLS_VERSION/SetEnv && \
	  xmake && \
	)
