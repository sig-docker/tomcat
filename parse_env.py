import sys
import os
import yaml


def die(*args):
    print("ERROR:", " ".join(args))
    sys.exit(1)


def env(k, default=""):
    return os.environ.get(k, default)


def split_vars(prefix, splits=1):
    for k, v in os.environ.items():
        t = k.split("_", splits)
        if len(t) > splits and t[0] == prefix:
            yield t[1:] + [v]


def dsn_var(dsn_name, k, default=None, ref=None):
    e = "TCDS_{}_{}".format(dsn_name, k)
    if default is None and e not in os.environ:
        if ref:
            return dsn_var(dsn_name, ref)
        die("Missing required variable:", e)
    return os.environ.get(e, default)


def dsn_vars():
    return [t for t in split_vars("TCDS", 2)]


def dsn_names():
    return {t[0] for t in dsn_vars()}


def dsn_resource(n):
    return {
        "name": dsn_var(n, "JNDI_NAME"),
        "attrs": {
            "auth": "Container",
            "type": "javax.sql.DataSource",
            "url": dsn_var(n, "JDBC_URL"),
            "username": dsn_var(n, "USER"),
            "password": dsn_var(n, "PASSWORD"),
            "driverClassName": dsn_var(n, "DRIVER_CLASS", "oracle.jdbc.OracleDriver"),
            "initialSize": "25",
            "maxIdle": "10",
            "maxTotal": "400",
            "maxWaitMillis": "30000",
            "minIdle": "10",
            "timeBetweenEvictionRunsMillis": "1800000",
            "testOnBorrow": "true",
            "testWhileIdle": "true",
            "accessToUnderlyingConnectionAllowed": "true",
            "validationQuery": "select * from dual",
            "validationQueryTimeout": "300",
            **{
                t[2]: t[3]
                for t in split_vars("TCDS", 3)
                if t[0] == n and t[1] == "ATTR"
            },
        },
    }


def dsn_link(n):
    return {
        "name": dsn_var(n, "JNDI_NAME"),
        "global_name": dsn_var(n, "JNDI_LINK_NAME", ref="JNDI_NAME"),
    }


def dsn_opts():
    names = dsn_names()
    return {
        "tomcat_resources": [dsn_resource(n) for n in names],
        "tomcat_resource_links": [dsn_link(n) for n in names],
    }


def ssl_opts():
    if env("ENABLE_SSL") == "yes":
        return {"tomcat_self_signed": "yes", "tomcat_ssl_enabled": "yes"}
    return {}


def connector_attr_opts():
    attrs = list(split_vars("CONNATTR"))
    if len(attrs) < 1:
        return {}
    return {
        "tomcat_connector_extra_attrs": [
            {"attribute": a[0], "value": a[1]} for a in attrs
        ]
    }


def go(fp):
    with fp:
        vars = {
            "tomcat_censor_ansible_output": env("CENSOR_ANSIBLE_OUTPUT", "yes"),
            "tomcat_memory_args": " ".join(
                [env("TOMCAT_MEMORY_ARGS"), env("TOMCAT_EXTRA_ARGS")]
            ),
            "tomcat_java_home": env("JAVA_HOME"),
            "tomcat_user": "root",
            "tomcat_group": "root",
            "tomcat_ssl_fqdn": env("TOMCAT_SSL_FQDN", "docker-self-signed"),
            "tomcat_ssl_org_name": "docker-self-signed",
            **ssl_opts(),
            **dsn_opts(),
            **connector_attr_opts(),
        }
        fp.write(yaml.dump(vars))


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        fp = sys.stdout
    else:
        fp = open(sys.argv[1], "w")
    go(fp)
