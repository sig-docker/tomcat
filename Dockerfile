# https://hub.docker.com/_/tomcat

#
# baseline release layer
#
FROM tomcat:jdk11-openjdk AS baseline

ENV APP_LOGS=/app_logs \
    CATALINA_USER=root \
    CATALINA_UID=0 \
    CATALINA_GROUP=root \
    CATALINA_GID=0

RUN rm -Rf $CATALINA_HOME/webapps.dist \
 && mkdir -p $APP_LOGS \
 && apt-get update -y  \
 && apt-get upgrade -y \
 && apt-get install -y python3-pip xtail gawk less unzip \
 && apt-get remove -y build-essential subversion mercurial git openssh-client \
      'libfreetype*' curl \
 && apt-get purge -y openssh-client \
 && apt-get clean autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /root/.cache/pip/* \
 && update-alternatives --install /usr/bin/python python $(which python3) 10

# Turn /etc/localtime into a regular file
RUN rm -f /etc/localtime \
 && cp -f /usr/share/zoneinfo/Etc/UTC /etc/localtime \
 && chmod 644 /etc/localtime

COPY parse_env.py run.sh set_tz.sh /
COPY ansible /ansible/

RUN mkdir -p /run.d /run.after_ansible /run.before_ansible \
 && cd /ansible \
 && pip3 install --no-cache-dir poetry \
 && poetry export -f requirements.txt --output requirements.txt \
 && pip install --no-cache-dir -r requirements.txt \
 && rm -rf /root/.cache/pypoetry \
 && mkdir -p galaxy \
 && ansible-galaxy install --roles-path galaxy -r tomcat-requirements.yml --force \
 && chmod 0755 /set_tz.sh

EXPOSE 8080
ENTRYPOINT ["/run.sh"]
CMD []

#
# tini uses the tini init system
#
FROM baseline AS tini

RUN apt-get update -y  \
 && apt-get install -y tini \
 && apt-get clean autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /root/.cache/pip/*

ENTRYPOINT ["/usr/bin/tini", "--", "/run.sh"]

#
# hardened layer follows the hexops best-practice recommendations
# https://github.com/hexops/dockerfile
#

FROM tini AS hardened

ENV CATALINA_USER=tomcat \
    CATALINA_UID=10000 \
    CATALINA_GROUP=tomcat \
    CATALINA_GID=10001

RUN groupadd -r -g ${CATALINA_GID} ${CATALINA_GROUP} \
 && useradd -rm -g ${CATALINA_GROUP} -s /bin/bash -u ${CATALINA_UID} ${CATALINA_USER} \
 && chgrp -R ${CATALINA_GROUP} $CATALINA_HOME \
 && chmod -R g-w $CATALINA_HOME \
 && chmod -R g+rX $CATALINA_HOME \
 && cd $CATALINA_HOME \
 && touch bin/setenv.sh \
 && mkdir -p logs temp webapps work conf \
 && chown -R ${CATALINA_USER} bin logs temp webapps work conf bin/setenv.sh /ansible \
 && sed -ie "s/^tomcat_user:.*/tomcat_user: ${CATALINA_USER}/" /ansible/group_vars/all/tomcat.yml \
 && sed -ie "s/^tomcat_group:.*/tomcat_group: ${CATALINA_GROUP}/" /ansible/group_vars/all/tomcat.yml \
 && chgrp ${CATALINA_USER} /etc/timezone /etc/localtime /ansible/group_vars/all/timezone.yml \
 && chmod g+rw /etc/timezone /etc/localtime /ansible/group_vars/all/timezone.yml

USER tomcat
