FROM tomcat:8.5.56-jdk8-openjdk

RUN rm -Rf $CATALINA_HOME/webapps.dist \
 && apt-get update -y  \
 && apt-get install -y python-pip xtail \
 && pip install ansible==2.9.2 lxml botocore boto3 \
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
