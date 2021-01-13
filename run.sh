#!/bin/bash

die () {
	echo "ERROR: $*"
	exit 1
}

dsnval () {
	var="TCDS_${1}_${2}"
	echo "${!var}"
}

setdsnvar () {
	export ${1}=$(dsnval $DSN ${1})
}

requiredsnvar () {
	setdsnvar "$1"
	val=$(eval echo \$$1)
	if [ -z "$val" ]; then
		if [ -z "$2" ]; then
			echo "ERROR: Missing required variable: TCDS_${DSN}_${1}"
			exit 1
		else
			export ${1}="$2"
		fi
	fi
}

printdsnresource () {
	cat <<EOF
  - name: $JNDI_NAME
    attrs:
      auth: Container
      type: javax.sql.DataSource
      url: "$JDBC_URL"
      username: $USER
      password: "$PASSWORD"
      driverClassName: $DRIVER_CLASS
      initialSize: 25
      maxIdle: 10
      maxTotal: 400
      maxWaitMillis: 30000
      minIdle: 10
      timeBetweenEvictionRunsMillis: 1800000
      testOnBorrow: true
      testWhileIdle: true
      accessToUnderlyingConnectionAllowed: true
      validationQuery: select * from dual
      validationQueryTimeout: 300

EOF
}

printdsnlink () {
	cat <<EOF
  - name: $JNDI_NAME
    global_name: $JNDI_LINK_NAME

EOF
}

build_tc_resources () {
	ansvars=/ansible/group_vars/all
	resfile=$ansvars/tomcat_resources.yml
	linkfile=$ansvars/tomcat_resource_links.yml

	mkdir -p $ansvars

	printf "tomcat_resources:\n" >$resfile
	printf "tomcat_resource_links:\n" >$linkfile

	for DSN in $(env |grep -oP '(?<=^TCDS_)[A-Za-z0-9_]+(?=_JDBC_URL=)'); do
		requiredsnvar JDBC_URL
		requiredsnvar JNDI_NAME
		requiredsnvar USER
		requiredsnvar PASSWORD
		requiredsnvar DRIVER_CLASS "oracle.jdbc.OracleDriver"
		requiredsnvar JNDI_LINK_NAME "$JNDI_NAME"

		printdsnresource >>$resfile
		printdsnlink >>$linkfile
	done
}

[ -z "$TOMCAT_MEMORY_ARGS" ] && die "TOMCAT_MEMORY_ARGS not defined"

TOMCAT_DYNAMIC=/ansible/group_vars/all/tomcat_dynamic.yml

for F in /run.d/*; do
  echo "Sourcing $F ..."
  . $F
done

if [ -z "$CENSOR_ANSIBLE_OUTPUT" ]; then
  CENSOR_ANSIBLE_OUTPUT="yes"
fi

build_tc_resources

cat >$TOMCAT_DYNAMIC <<EOF
tomcat_censor_ansible_output: "$CENSOR_ANSIBLE_OUTPUT"
tomcat_memory_args: "$TOMCAT_MEMORY_ARGS $TOMCAT_EXTRA_ARGS"
tomcat_java_home: $JAVA_HOME
tomcat_user: root
tomcat_group: root
tomcat_ssl_fqdn: docker-self-signed
tomcat_ssl_org_name: docker-self-signed
EOF

if [ "$ENABLE_SSL" = 'yes' ]; then
	cat >>$TOMCAT_DYNAMIC <<EOF
tomcat_self_signed: yes
tomcat_ssl_enabled: yes
EOF
fi

cd /ansible || die "failed to cd to /ansible"
ansible-playbook tomcat-playbook.yml -t tomcat_conf --extra-vars "tomcat_root=$CATALINA_HOME" || die "ansible error"

cd $CATALINA_HOME || die "failed to cd to CATALINA_HOME ($CATALINA_HOME)"

xtail ${APP_LOGS} &

bin/catalina.sh run
