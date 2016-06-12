DEV=20080411413fc082

.PHONY: compile
zbs: all install
all: compile
compile:
	@ANT_OPTS="-Dant.logger.defaults=./logger.properties" ant -logger 'org.apache.tools.ant.listener.AnsiColorLogger' debug
install:
	adb -s ${DEV} install -r bin/rcd-debug.apk
	adb -s ${DEV} shell am start -a android.intent.action.MAIN -n ua.zhumarin.rcd/.MainActivity
	# @ANT_OPTS="-Dant.logger.defaults=./logger.properties" ant -Dant.logger.defaults=./logger.properties -logger 'org.apache.tools.ant.listener.AnsiColorLogger' installd start
clean:
	rm -rf bin/classes/*
install2:
	adb -s 20080411413fc082 install -r bin/rcd-debug.apk
