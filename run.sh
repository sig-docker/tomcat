#!/bin/bash

shopt -s nullglob

die () {
	echo "ERROR: $*"
	exit 1
}

[ -z "$TOMCAT_MEMORY_ARGS" ] && die "TOMCAT_MEMORY_ARGS not defined"

TOMCAT_DYNAMIC=/ansible/group_vars/all/tomcat_dynamic.yml

for V in $(env |grep "^APPEND\(_\|=\)" |cut -d '=' -f 1); do
  echo "Handling $V ..."
  eval V=\$$V
  FP=$(echo "$V" | head -n 1)
  if [ -f "$FP" ]; then
    ORG="/.sig-tomcat-originals/${FP}"
    if [ -f "$ORG" ]; then
      BK="/.sig-tomcat-backups/${FP}.$(date '+%Y-%m-%d_%H.%M.%S')"
    else
      BK="$ORG"
    fi
    echo "Backing up $FP to $BK"
    mkdir -p "$(dirname $BK)" || die "Error creating backup directory"
    cp "$FP" "$BK" || die "Error backing up append file"
    if [ -f "$ORG" ]; then
      echo "Restoring original from $ORG"
      cp -f "$ORG" "$FP" || die "Error restoring original prior to append"
    fi
  fi
  echo "Appending to $FP"
  echo "$V" |tail -n +2 >> $FP
done

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

for V in $(env |grep "^TC_ANS_[a-zA-Z_]*" |cut -d '=' -f 1 |sort); do
  echo "Handling $V ..."
  eval V=\$$V
  echo "$V" |ansible-playbook -i inventory.ini --extra-vars "tomcat_root=$CATALINA_HOME" /dev/stdin ||die "error handling Ansible playbook variable"
done

if [ -z "$TEST_CONF_ONLY" ]; then
	cd $CATALINA_HOME || die "failed to cd to CATALINA_HOME ($CATALINA_HOME)"
 
  xtail ${APP_LOGS} &

	bin/catalina.sh run
else
	echo "Configuration test succeeded."	
fi
