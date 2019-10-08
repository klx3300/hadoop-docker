# Creates pseudo distributed hadoop 2.7.1
#
# docker build -t sequenceiq/hadoop .

FROM centos:7

USER root

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin

# install dev tools
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum clean all \
    && rpm --rebuilddb \
    && yum install -y curl which tar sudo openssh-server openssh-clients rsync git \
    && yum update -y libselinux \
    && ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key \
    && ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key \
    && ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa \
    && cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys \
    && curl -L -o 'jdk.rpm' 'https://lax.imzhwk.com/jdk7.rpm' \
    && rpm -i jdk.rpm \
    && rm jdk.rpm \
    && rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java

# && curl -LO 'http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie' \

# download native support
RUN mkdir -p /tmp/native \
    && git clone https://github.com/klx3300/hadoop-docker.git /tmp/native \
    && curl -o /tmp/hadoop.tar.gz http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-2.8.5/hadoop-2.8.5.tar.gz \
    && tar -C /usr/local/ -zxvf /tmp/hadoop.tar.gz \
    && cd /usr/local && ln -s ./hadoop-2.8.5 hadoop

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_PREFIX=/usr/local/hadoop\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh \
    && sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh \
    && mkdir $HADOOP_PREFIX/input \
    && cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input
#RUN . $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh


# pseudo distributed
ADD core-site.xml.template $HADOOP_PREFIX/etc/hadoop/core-site.xml.template
ADD hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

ADD mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

ADD ssh_config /root/.ssh/config

ADD bootstrap.sh /etc/bootstrap.sh

RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml \
    && $HADOOP_PREFIX/bin/hdfs namenode -format \
    && rm -rf /usr/local/hadoop/lib/native \
    && mv /tmp/native /usr/local/hadoop/lib \
    && chmod 600 /root/.ssh/config \
    && chown root:root /root/.ssh/config \
    && chown root:root /etc/bootstrap.sh \
    && chmod 700 /etc/bootstrap.sh

# # installing supervisord
# RUN yum install -y python-setuptools
# RUN easy_install pip
# RUN curl https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -o - | python
# RUN pip install supervisor
#
# ADD supervisord.conf /etc/supervisord.conf


ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh \
    && chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh \
    && ls -la /usr/local/hadoop/etc/hadoop/*-env.sh \
    && sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config \
    && echo "UsePAM no" >> /etc/ssh/sshd_config \
    && echo "Port 2122" >> /etc/ssh/sshd_config \
    && /usr/sbin/sshd \
    && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -mkdir -p /user/root \
    && $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh && $HADOOP_PREFIX/sbin/start-dfs.sh && $HADOOP_PREFIX/bin/hdfs dfs -put $HADOOP_PREFIX/etc/hadoop/ input

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
