#
# Redmine 3.2
#

FROM centos:6.7

MAINTAINER Jozuko "jozuko.dev@gmail.com"


#######################################  environment  ########################################
ENV INSTALL_DIR=/opt/redmine \
    TMP_DIR=/usr/local/src/tmp \
    ROOT_PASSWORD=rootpw \
    USER= \
    USER_PASSWORD= \
    APACHE_USER=apache \
    LOCALTIME=Japan \
    TIMEZONE=Asia/Tokyo \
    REDMINE_HOST= \
    SMTP_ENABLE= \
    SMTP_METHOD= \
    SMTP_STARTTLS= \
    SMTP_HOST= \
    SMTP_PORT= \
    SMTP_DOMAIN= \
    SMTP_AUTHENTICATION= \
    SMTP_USER= \
    SMTP_PASS=

#######################################  copy settng file  ########################################

RUN mkdir -p ${TMP_DIR}/sql; \
    mkdir -p ${TMP_DIR}/config; \
    mkdir -p ${TMP_DIR}/bin; \
    mkdir -p ${TMP_DIR}/hooks/git; \
    mkdir -p ${TMP_DIR}/hooks/svn; \
    mkdir -p ${TMP_DIR}/httpd-conf; \
    mkdir -p ${TMP_DIR}/jenkins

COPY supervisord.conf ${TMP_DIR}/
COPY update.sh ${TMP_DIR}/
COPY sql/*  ${TMP_DIR}/sql/
COPY config/* ${TMP_DIR}/config/
COPY bin/*  ${TMP_DIR}/bin/
COPY hooks/git/*  ${TMP_DIR}/hooks/git/
COPY hooks/svn/*  ${TMP_DIR}/hooks/svn/
COPY httpd-conf/*  ${TMP_DIR}/httpd-conf/
COPY jenkins/*  ${TMP_DIR}/jenkins/

RUN cd ${TMP_DIR}; \
    find ./ -type f | xargs sed -i "s#\%INSTALL_DIR\%#${INSTALL_DIR}#g"


#######################################  os  ########################################

# install base module
RUN yum -y update
RUN yum -y install openssh openssh-server openssh-clients git sudo tar which wget unzip sudo

# setup root
RUN echo "root:${ROOT_PASSWORD}" | chpasswd


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
RUN /etc/init.d/mysqld start; \
    mysql < ${TMP_DIR}/sql/createdb.sql


########################################  redmine  ########################################

# install redmine
RUN mkdir -p ${INSTALL_DIR}; \
    cd /usr/local/src/; \
    svn co http://svn.redmine.org/redmine/branches/3.2-stable ${INSTALL_DIR}

# database setting
RUN cp -f ${TMP_DIR}/config/database.yml ${INSTALL_DIR}/config/database.yml

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

# jozu_gantt(ガントチャートプラグイン)
RUN git clone https://github.com/jozuko/jozu_gantt.git ${INSTALL_DIR}/plugins/jozu_gantt

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

RUN mkdir -p /etc/opt/redmine/; \
    cp -f ${TMP_DIR}/config/svnauthz /etc/opt/redmine/svnauthz


########################################  scm設定  ########################################


RUN mkdir -p $INSTALL_DIR/bin; \
    mkdir -p /var/opt/redmine/git /var/opt/redmine/svn /var/opt/redmine/maven

# scm-creator : create ${INSTALL_DIR}/config/scm.yml
RUN cp -f ${TMP_DIR}/config/scm.yml ${INSTALL_DIR}/config/scm.yml; \
    cp -f ${TMP_DIR}/bin/scm-post-create ${INSTALL_DIR}/bin/scm-post-create; \
    cp -f ${TMP_DIR}/bin/sync-scm ${INSTALL_DIR}/bin/sync-scm; \
    mkdir -p ${INSTALL_DIR}/hooks/git; \
    mkdir -p ${INSTALL_DIR}/hooks/svn; \
    cp -f ${TMP_DIR}/hooks/git/post-receive ${INSTALL_DIR}/hooks/git/post-receive; \
    cp -f ${TMP_DIR}/hooks/svn/post-commit ${INSTALL_DIR}/hooks/svn/post-commit


########################################  [setting]apache  ########################################

RUN chown -R $APACHE_USER:$APACHE_USER $INSTALL_DIR; \
    chown -R $APACHE_USER:$APACHE_USER /var/opt/redmine


##########################################  jenkins  ########################################

# install jenkins
RUN wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo; \
    rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key; \
    yum install -y java-1.8.0-openjdk; \
    yum install -y jenkins

# mod_auth_mysql-3.0.0-11.el6_0.1.src.rpm for redmine
RUN rpm -vi --force http://vault.centos.org/6.7/os/Source/SPackages/mod_auth_mysql-3.0.0-11.el6_0.1.src.rpm; \
    cd /root/rpmbuild/SOURCES; \
    wget http://www.redmine.org/attachments/download/6443/mod_auth_mysql-3.0.0-redmine.patch; \
    sed -i -e "s/Release: 11%{?dist}.1/Release: 11%{?dist}.1.redmine/g" /root/rpmbuild/SPECS/mod_auth_mysql.spec; \
    sed -i -e "s/Patch10: mod_auth_mysql-3\.0\.0-CVE-2008-2384\.patch/Patch10: mod_auth_mysql-3\.0\.0-CVE-2008-2384\.patch\nPatch20: mod_auth_mysql-3\.0\.0-redmine\.patch/g" /root/rpmbuild/SPECS/mod_auth_mysql.spec; \
    sed -i -e "s/%patch10 -p1 -b \.cve2384/%patch10 -p1 -b \.cve2384\n%patch20 -p1/g" /root/rpmbuild/SPECS/mod_auth_mysql.spec; \
    rpmbuild -bb /root/rpmbuild/SPECS/mod_auth_mysql.spec; \
    rpm -vi --force /root/rpmbuild/RPMS/x86_64/mod_auth_mysql-3.0.0-11.el6.1.redmine.x86_64.rpm

# create httpd-conf
RUN cp -f ${TMP_DIR}/httpd-conf/jenkins.conf /etc/httpd/conf.d/jenkins.conf

# edit sysconfig
RUN sed -i 's/JENKINS_ARGS=""/JENKINS_ARGS="--prefix=\/jenkins"/' /etc/sysconfig/jenkins

# get jenkins plugin-list
RUN mkdir -p /var/lib/jenkins/plugins; \
    chown jenkins.jenkins /var/lib/jenkins/plugins; \
    service jenkins start; \
    sleep 60; \
    wget -O $INSTALL_DIR/bin/jenkins-cli.jar http://localhost:8080/jenkins/jnlpJars/jenkins-cli.jar; \
    curl -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- http://localhost:8080/updateCenter/byId/default/postBack; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin reverse-proxy-auth-plugin; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin git; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin redmine; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin dashboard-view; \
    mkdir -p /var/lib/jenkins; \
    cp -f ${TMP_DIR}/jenkins/config.xml /var/lib/jenkins/config.xml; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ restart


########################################  after-setting  ########################################

# svn auth
RUN mkdir -p /etc/httpd/Apache/Authn; \
    cp ${INSTALL_DIR}/extra/svn/Redmine.pm /etc/httpd/Apache/Authn/

# edit /etc/httpd/conf.d/redmine.conf
RUN cp -f ${TMP_DIR}/httpd-conf/redmine.conf /etc/httpd/conf.d/redmine.conf; \
    cp -f ${TMP_DIR}/httpd-conf/vcs.conf /etc/httpd/conf.d/vcs.conf


########################################  Supervisord  ########################################

RUN wget http://peak.telecommunity.com/dist/ez_setup.py; \
    python ez_setup.py; \
    easy_install distribute; \
    wget https://bootstrap.pypa.io/get-pip.py; \
    python get-pip.py

RUN pip install supervisor; \
    cp -f ${TMP_DIR}/supervisord.conf /etc/supervisord.conf

RUN git clone https://github.com/Supervisor/initscripts.git; \
    cd initscripts/; chmod +x ./redhat*; \
    cp redhat-init-jkoppe /etc/init.d/supervisord; \
    cp redhat-sysconfig-jkoppe /etc/sysconfig/supervisord; \
    chkconfig --add supervisord


########################################  escape data  ########################################

# escape data
RUN date > /opt/redmine/initialized; \
    mkdir -p /opt/redmine/initdatas; \
    cp -p /opt/redmine/initialized /opt/redmine/files/; \
    cp -p /opt/redmine/initialized /var/opt/redmine/; \
    cp -p /opt/redmine/initialized /var/lib/mysql/; \
    cd /; \
    tar czf /opt/redmine/initdatas/db.tar.gz var/lib/mysql; \
    tar czf /opt/redmine/initdatas/files.tar.gz opt/redmine/files; \
    tar czf /opt/redmine/initdatas/repo.tar.gz var/opt/redmine


# create initialize shell for data recovery
RUN cp -f ${TMP_DIR}/update.sh /root/update.sh


########################################  start container  ########################################

# expose for httpd
EXPOSE 80

# volume setting
VOLUME ["/opt/redmine/files", "/var/opt/redmine", "/var/lib/mysql"]

# start supervisord
CMD ["/usr/bin/supervisord"]
