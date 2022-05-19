#!/bin/bash

shopt -s nullglob

die () {
	echo "ERROR: $*"
	exit 1
}

[ -z "$TOMCAT_MEMORY_ARGS" ] && die "TOMCAT_MEMORY_ARGS not defined"

TOMCAT_DYNAMIC=/ansible/group_vars/all/tomcat_dynamic.yml

for F in /run.d/*; do
  echo "Sourcing $F ..."
  . $F
done

python3 /parse_env.py $TOMCAT_DYNAMIC

cd ${CATALINA_HOME}/lib
for url in $TOMCAT_DOWNLOAD_LIBS; do
  wget "$url" ||die "download error"
done

cd /ansible || die "failed to cd to /ansible"
ansible-playbook tomcat-playbook.yml -i inventory.ini -t tomcat_conf --extra-vars "tomcat_root=$CATALINA_HOME" || die "ansible error"

if [ -z "$TEST_CONF_ONLY" ]; then
	cd $CATALINA_HOME || die "failed to cd to CATALINA_HOME ($CATALINA_HOME)"
 
  xtail ${APP_LOGS} &

	bin/catalina.sh run
else
	echo "Configuration test succeeded."	
fi
