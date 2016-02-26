#
# Redmine 3.2
#

FROM centos:6.7

MAINTAINER Jozuko "jozuko.dev@gmail.com"

# ENV http_proxy=http://<ip address>:8080 \
#     https_proxy=http://<ip address>:8080 \
#     no_proxy=/var/run/docker.sock,localhost



#######################################  os  ########################################

ENV DEF_USER=jozuko

# install base module
RUN yum -y update
RUN yum -y install openssh openssh-server openssh-clients git sudo tar which wget unzip sudo

# setup root
RUN echo "root:rootpw" | chpasswd

# setup user
RUN useradd $DEF_USER; \
    echo "$DEF_USER:$DEF_USER" | chpasswd

# setup sudoers
RUN sed -i -e "s/Defaults *requiretty/# Defaults requiretty/" /etc/sudoers; \
    echo "$DEF_USER ALL=(ALL) ALL" >> /etc/sudoers.d/$DEF_USER; \
    chmod 440 /etc/sudoers.d/$DEF_USER

# setup TimeZone
RUN mv /etc/localtime /etc/localtime.org; \
    cp /usr/share/zoneinfo/Japan /etc/localtime; \
    sed -i "s/^ZONE/#ZONE/g" /etc/sysconfig/clock; \
    sed -i "s/^UTC/#UTC/g" /etc/sysconfig/clock; \
    echo "ZONE=\"Asia/Tokyo\"" >> /etc/sysconfig/clock; \
    echo "UTC=\"False\"" >> /etc/sysconfig/clock

# start supervisord
CMD ["/bin/bash"]
