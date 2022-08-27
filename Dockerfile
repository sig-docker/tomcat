# https://hub.docker.com/_/tomcat

#
# baseline release layer
#
FROM tomcat:jdk8-openjdk AS baseline

ENV APP_LOGS=/app_logs

RUN rm -Rf $CATALINA_HOME/webapps.dist \
 && mkdir -p $APP_LOGS \
 && apt-get update -y  \
 && apt-get upgrade -y \
 && apt-get install -y python3-pip xtail gawk \
 && pip3 install ansible==2.10.7 lxml \
 && apt-get remove -y build-essential subversion mercurial git openssh-client \
      'libfreetype*' curl \
 && apt-get purge -y openssh-client \
 && apt-get clean autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* /root/.cache/pip/*

COPY ansible /ansible/
RUN mkdir -p /run.d \
 && cd /ansible \
 && mkdir -p galaxy \
 && ansible-galaxy install --roles-path galaxy -r tomcat-requirements.yml --force

COPY parse_env.py run.sh /

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

RUN groupadd -r -g 10001 tomcat \
 && useradd -rm -g tomcat -s /bin/bash -u 10000 tomcat \
 && chgrp -R tomcat $CATALINA_HOME \
 && chmod -R g-w $CATALINA_HOME \
 && chmod -R g+rX $CATALINA_HOME \
 && cd $CATALINA_HOME \
 && touch bin/setenv.sh \
 && mkdir -p logs temp webapps work conf \
 && chown -R tomcat bin logs temp webapps work conf bin/setenv.sh /ansible \
 && sed -ie 's/^tomcat_user:.*/tomcat_user: tomcat/' /ansible/group_vars/all/tomcat.yml
 && sed -ie 's/^tomcat_group:.*/tomcat_group: tomcat/' /ansible/group_vars/all/tomcat.yml

USER tomcat
