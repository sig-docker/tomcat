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

* `TOMCAT_EXTRA_ARGS` - Extra command-line arguments for the Tomcat process.
  * Example: `TOMCAT_EXTRA_ARGS='-Duser.timezone=America/Chicago'`

* `TOMCAT_SSL_FQDN` - If specified along with `ENABLE_SSL='yes'` this value will
  be used to set the hostname on the self-signed certificate. By if unspecified
  the hostname of the container will be used.

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

## Links

* [Official releases on Docker Hub](https://hub.docker.com/r/sigcorp/tomcat)
