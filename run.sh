#!/bin/bash

die () {
	echo "ERROR: $*"
	exit 1
}

[ -z "$TOMCAT_MEMORY_ARGS" ] && die "TOMCAT_MEMORY_ARGS not defined"

for F in /run.d/*; do
  echo "Sourcing $F ..."
  . $F
done

if [ -z "$CENSOR_ANSIBLE_OUTPUT" ]; then
  CENSOR_ANSIBLE_OUTPUT="yes"
fi

cat >/ansible/group_vars/all/tomcat_dynamic.yml <<EOF
tomcat_censor_ansible_output: "$CENSOR_ANSIBLE_OUTPUT"
tomcat_memory_args: "$TOMCAT_MEMORY_ARGS $TOMCAT_EXTRA_ARGS"
tomcat_java_home: $JAVA_HOME
EOF

cd /ansible || die "failed to cd to /ansible"
ansible-playbook tomcat-playbook.yml -t tomcat_conf --extra-vars "tomcat_root=$CATALINA_HOME" || die "ansible error"

cd $CATALINA_HOME || die "failed to cd to CATALINA_HOME ($CATALINA_HOME)"
bin/catalina.sh run
