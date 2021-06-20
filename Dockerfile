# https://hub.docker.com/_/tomcat
FROM tomcat:8.5.68-jdk8-openjdk

ENV APP_LOGS=/app_logs

RUN rm -Rf $CATALINA_HOME/webapps.dist \
 && mkdir -p $APP_LOGS \
 && apt-get update -y  \
 && apt-get upgrade -y \
 && apt-get install -y python3 python3-pip xtail \
 && pip3 install ansible==2.10.7 lxml \
 && apt-get remove -y build-essential mercurial git openssh-client python3-pip \
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
