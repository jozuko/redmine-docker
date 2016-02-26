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



#######################################  ssh  ########################################

# setup sshd
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key; \
    ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key; \
    sed -i "s/#UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config; \
    sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config; \
    sed -i "s/#UseDNS yes/UseDNS no/g" /etc/ssh/sshd_config

# expose for sshd
EXPOSE 22



####################################### EPEL #######################################

RUN yum -y install epel-release; \
    sed -i "s/enabled=1/enabled=0/g" /etc/yum.repos.d/epel.repo; \
    yum -y --enablerepo=epel install libmcrypt-devel



#######################################  pre-install  ########################################

RUN yum -y groupinstall "Development Tools"; \
    yum -y --nogpgcheck install mysql \
                                mysql-server \
                                mysql-devel \
                                ImageMagick \
                                ImageMagick-devel \
                                ipa-pgothic-fonts \
                                httpd \
                                httpd-devel \
                                apr-devel \
                                openssl-devel \
                                curl-devel \
                                zlib-devel \
                                mod_auth_mysql \
                                mod_dav_svn \
                                mod_wsgi  \
                                mod_perl \
                                perl-Apache-DBI \
                                perl-Digest-SHA \
                                libical \
                                python-docutils \
                                rpmdevtools \
                                readline-devel \
                                ncurses-devel \
                                gdbm-devel \
                                tcl-devel \
                                db4-devel \
                                libyaml-devel \
                                glibc-devel \
                                libxml2-devel \
                                libxslt-devel \
                                sqlite-devel \
                                libffi-devel
RUN chkconfig --add mysqld; \
    chkconfig mysqld on; \
    service mysqld start



#######################################  ruby  ########################################

RUN cd /usr/local/src; \
    curl -O https://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.3.tar.gz; \
    tar xvf ruby-2.2.3.tar.gz; \
    cd ruby-2.2.3; \
    ./configure --disable-install-doc; \
    make; \
    make install


# install bundler, rake, rake-compiler
RUN gem install -f bundler --no-rdoc --no-ri; \
    gem install -f rake --no-rdoc --no-ri; \
    gem install -f rake-compiler --no-rdoc --no-ri


# install passenger
RUN gem install rubygems-update; \
    update_rubygems; \
    gem install passenger --no-rdoc --no-ri; \
    passenger-install-apache2-module --auto



########################################  mysql  ########################################

# create database
RUN mkdir -p /usr/local/src/scripts/; \
    echo "CREATE DATABASE redmine DEFAULT CHARACTER SET utf8;"                              > /usr/local/src/scripts/createdb.sql; \
    echo "GRANT ALL PRIVILEGES ON redmine.* TO redmine@localhost IDENTIFIED BY 'redmine';" >> /usr/local/src/scripts/createdb.sql


RUN /etc/init.d/mysqld start; \
    mysql < /usr/local/src/scripts/createdb.sql



########################################  redmine  ########################################

# install redmine
ENV INSTALL_DIR=/opt/redmine
RUN mkdir -p ${INSTALL_DIR}; \
    cd /usr/local/src/; \
    svn co http://svn.redmine.org/redmine/branches/3.2-stable ${INSTALL_DIR}


# database setting
#COPY scripts/database.yml ${INSTALL_DIR}/config/
RUN mkdir -p /usr/local/src/scripts/; \
    echo "production:"           > ${INSTALL_DIR}/config/database.yml; \
    echo "  adapter: mysql2"    >> ${INSTALL_DIR}/config/database.yml; \
    echo "  database: redmine"  >> ${INSTALL_DIR}/config/database.yml; \
    echo "  host: localhost"    >> ${INSTALL_DIR}/config/database.yml; \
    echo "  username: redmine"  >> ${INSTALL_DIR}/config/database.yml; \
    echo "  password: redmine"  >> ${INSTALL_DIR}/config/database.yml; \
    echo "  encoding: utf8"     >> ${INSTALL_DIR}/config/database.yml


# install gem packages
RUN cd ${INSTALL_DIR}; \
    gem install nokogiri -- --use-system-libraries=true --with-xml2-include=/usr/include/libxml2/; \
    bundle install --path vendor/bundler --without development test postgresql sqlite

# create secret token
RUN /etc/init.d/mysqld start; \
    cd ${INSTALL_DIR}; \
    bundle exec rake generate_secret_token; \
    RAILS_ENV=production bundle exec rake db:migrate; \
    RAILS_ENV=production REDMINE_LANG=ja bundle exec rake redmine:load_default_data


########################################  redmine-plugins  ########################################

# create work directory
RUN mkdir -p cd /usr/local/src/redmine-plugins


# redmine_xls_export（チケットをExcelにエクスポートするプラグイン）
RUN cd /usr/local/src; \
    git clone https://github.com/two-pack/redmine_xls_export.git redmine-plugins/redmine_xls_export; \
    cd redmine-plugins/redmine_xls_export; \
    git checkout 0.2.1.t9; \
    cd /usr/local/src; \
    cp -fra redmine-plugins/redmine_xls_export ${INSTALL_DIR}/plugins/


# redmine_plugin_views_revisions(redmine_xls_exportに必要なplugin)
RUN cd /usr/local/src; \
    wget -P redmine-plugins http://www.redmine.org/attachments/download/7705/redmine_plugin_views_revisions_v001.zip; \
    yes | unzip -q redmine-plugins/redmine_plugin_views_revisions_v001.zip; \
    mv redmine_plugin_views_revisions ${INSTALL_DIR}/plugins/redmine_plugin_views_revisions; \
    rm -f redmine-plugins/redmine_plugin_views_revisions_v001.zip


# redmine_code_review（コードレビュープラグイン）
RUN cd /usr/local/src; \
    wget -P redmine-plugins https://bitbucket.org/haru_iida/redmine_code_review/downloads/redmine_code_review-0.7.0.zip; \
    yes | unzip -q redmine-plugins/redmine_code_review-0.7.0.zip; \
    mv redmine_code_review ${INSTALL_DIR}/plugins/redmine_code_review; \
    rm -f redmine-plugins/redmine_code_review-0.7.0.zip


# advanced_roadmap(ロードマップを表示するプラグイン)
RUN cd /usr/local/src; \
    wget --no-check-certificate -P redmine-plugins https://redmine.ociotec.com/attachments/download/332/advanced_roadmap%20v0.9.0.tar.gz; \
    tar zxf "redmine-plugins/advanced_roadmap v0.9.0.tar.gz"; \
    mv "advanced_roadmap v0.9.0" ${INSTALL_DIR}/plugins/advanced_roadmap; \
    rm -f "redmine-plugins/advanced_roadmap v0.9.0.tar.gz"


# scm-creator（redmine上でリポジトリを作成するプラグイン）
RUN cd /usr/local/src; \
    svn export -r 142 http://subversion.andriylesyuk.com/scm-creator redmine_scm; \
    mv redmine_scm ${INSTALL_DIR}/plugins/redmine_scm


# redmine_drafts(作成中のチケットを保存)
RUN git clone https://github.com/jbbarth/redmine_drafts.git ${INSTALL_DIR}/plugins/redmine_drafts


# clipboard_image_paste(チケットにイメージをコピペできる)
RUN git clone https://github.com/peclik/clipboard_image_paste.git ${INSTALL_DIR}/plugins/clipboard_image_paste

# redmine_banner(Redmineのサイト上部に管理者からのメッセージを表示できる)
RUN git clone https://github.com/akiko-pusu/redmine_banner.git ${INSTALL_DIR}/plugins/redmine_banner


# update database
RUN /etc/init.d/mysqld start; \
    cd ${INSTALL_DIR}; \
    gem install nokogiri -- --use-system-libraries=true --with-xml2-include=/usr/include/libxml2/; \
    sed -i -e "s/gem \"nokogiri\"/#gem \"nokogiri\"/g" Gemfile; \
    bundle install --path vendor/bundler --without development test postgresql sqlite; \
    RAILS_ENV=production bundle exec rake redmine:plugins; \
    RAILS_ENV=production bundle exec rake redmine:plugins:migrate; \
    RAILS_ENV=production bundle exec rake generate_secret_token; \
    RAILS_ENV=production bundle exec rake db:migrate; \
    RAILS_ENV=production bundle exec rake tmp:cache:clear; \
    RAILS_ENV=production bundle exec rake tmp:sessions:clear; \
    RAILS_ENV=production bundle exec rake redmine:plugins:process_version_change


########################################  [setting]svn  ########################################


CMD ["/bin/bash"]

