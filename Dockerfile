# https://hub.docker.com/_/tomcat
FROM tomcat:8.5-jdk8-openjdk

ENV APP_LOGS=/app_logs

RUN rm -Rf $CATALINA_HOME/webapps.dist \
 && mkdir -p $APP_LOGS \
 && apt-get update -y  \
 && apt-get upgrade -y \
 && apt-get install -y python-pip xtail \
 && pip install ansible==2.10.7 lxml \
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

COPY run.sh /run.sh

EXPOSE 8080
CMD /run.sh
