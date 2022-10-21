# Parameterized Tomcat

This image extends the [official Tomcat image](https://hub.docker.com/_/tomcat)
with launch-time parameterization including:

* [Memory settings](#memory-settings)
* Tomcat and Java command line options
* JNDI data sources

## Environment Variables
### Required Variables

* `TOMCAT_MEMORY_ARGS` - Java memory parameters for the Tomcat process.
  * Example: `TOMCAT_MEMORY_ARGS='-Xms1024m -Xmx2048m'`

### Optional Variables

* `CENSOR_ANSIBLE_OUTPUT` - By default, the output of certain steps in the 
  Ansible-based parameterization process are "censored" to prevent secrets 
  appearing in log files. If you are having trouble with JNDI resources, you can
  set this to `no` to log what is being configured.
  * `yes` - _default_ - Prevent secrets appearing in log output
  * `no` - Log values during JNDI setup
  * **Important Note:** This value must be passed as a *string* as it appears 
    here. If you are using a YAML-based deployment syntax (as with Sceptre) you
    will need to quote the value to prevent the YAML interpreter seeing it as a
    boolean.

* `ENABLE_SSL` - When `yes` a self-signed certificate will be generated and the
  SSL listener will be available on port 8443.
  * `yes` - Generate a self-signed certificate and listen for HTTPS on 8443
  * `no` - _default_ - Disable SSL/HTTPS support
  * **Important Note:** This value must be passed as a *string* as it appears 
    here. If you are using a YAML-based deployment syntax (as with Sceptre) you
    will need to quote the value to prevent the YAML interpreter seeing it as a
    boolean.
    
* `TOMCAT_DOWNLOAD_LIBS` - A space- or comma-separated list of URLS to download
  into `$CATALINA_HOME/lib`. This is useful for adding JDBC dependencies.

* `TOMCAT_EXTRA_ARGS` - Extra command-line arguments for the Tomcat process.
  * Example: `TOMCAT_EXTRA_ARGS='-Duser.timezone=America/Chicago'`

* `TOMCAT_SSL_FQDN` - If specified along with `ENABLE_SSL='yes'` this value will
  be used to set the hostname on the self-signed certificate.
  * _default_ - `docker-self-signed`

### Specifying Data Sources

JNDI data sources are specified using variables prefixed with `TCDS_` and 
following this name format:

* `TCDS_<PREFIX>_<ARGUMENT>`

Example:
```
TCDS_BP_JDBC_URL='jdbc:oracle:thin:@db.school.edu:1521:PROD'
TCDS_BP_USER='banproxy'
TCDS_BP_JNDI_NAME='jdbc/bannerDataSource'
TCDS_BP_PASSWORD='super_secret'
TCDS_BP_ATTR_maxTotal=800
```

**NB:** The prefix (`BP` in the example above) has no functional meaning and is
only used to group the arguments.

#### Required Data Source Arguments

* `JDBC_URL` - JDBC URL of the data source
* `JNDI_NAME` - Name assigned to the JNDI resource
* `USER` - Username for the JDBC connection
* `PASSWORD` - Password for the JDBC connection

#### Optional Data Source Arguments

* `DRIVER_CLASS` - JDBC driver class for the connection
  * _default_: `oracle.jdbc.OracleDriver`
* `JNDI_LINK_NAME` - Name assigned to the JNDI link
  * _default_: Same as `JNDI_NAME`
  
#### Extended Attributes

Beyond the basic data source arguments, you can provide any arbitrary argument
by prefixing with `ATTR_` For example, to set `maxTotal` in the `BP` data
source:

```
TCDS_BP_ATTR_maxTotal=800
```

The following attribute defaults are provided:

* `initialSize`: `25`
* `maxIdle`: `10`
* `maxTotal`: `400`
* `maxWaitMillis`: `30000`
* `minIdle`: `10`
* `timeBetweenEvictionRunsMillis`: `1800000`
* `testOnBorrow`: `true`
* `testWhileIdle`: `true`
* `accessToUnderlyingConnectionAllowed`: `true`
* `validationQuery`: `select * from dual`
* `validationQueryTimeout`: `300`

### Extra Connection Attributes

Additional attributes may be added to the HTTP and HTTPS `Connector` tags in
`server.xml` by prefixing them with `CONNATTR_`. For example:

```
CONNATTR_relaxedQueryChars="|{}[]:"
```

### Inline Ansible Playbooks

Additional configuration tasks can be performed at launch time using [Ansible
playbooks](https://docs.ansible.com/ansible/latest/user_guide/playbooks.html)
configured in the startup environment. Any environment variable with the prefix
`TC_ANS_` will be treated as a playbook and processed immediately after the
Tomcat configuration playbook is run. These variables will be processed in
lexical order.

A common use-case for this feature would be to inject a keystore for SAML
support from a secrets manager. This can be done by base64-encoding the file and
using the [Ansible copy module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)
to place it in the file system. To do this, set a variable (e.g.
`TC_ANS_KEYSTORE`) to a value like:

```yaml
---
- hosts: localhost
  tasks:
    - set_fact:
        file_content: |
          <Base64 Data>

    - name: Create keystore
      copy:
        dest: /opt/saml_keystore.jks
        owner: root
        group: tomcat
        mode: "0640"
        content: '{{ file_content | b64decode }}'
```

### Inline Ansible Variables

Additional Ansible variables can be passed in YAML format using environment
variables. Any environment variable with the prefix `TC_VAR_` will be put
into a global group variable file prior to any Ansible playbooks are executed.

## Provided Environment Variables

This image adds a number of variables to those provided by the official Tomcat
image ([described on their Docker Hub page](https://hub.docker.com/_/tomcat/)):

| Var            | baseline | hardened |
|----------------|----------|----------|
| CATALINA_USER  | root     | tomcat   |
| CATALINA_UID   | 0        | 10000    |
| CATALINA_GROUP | root     | tomcat   |
| CATALINA_GID   | 0        | 10001    |

**Note:** The values for UID & GID are currently
          [https://github.com/sig-docker/tomcat/issues/26](being discussed) and
          may change.

## Links

* [Official releases on Docker Hub](https://hub.docker.com/r/sigcorp/tomcat)
