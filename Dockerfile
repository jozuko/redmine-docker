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

RUN mkdir -p /etc/opt/redmine/; \
    echo "#グループの設定"                       > /etc/opt/redmine/svnauthz; \
    echo "[groups]"                             >> /etc/opt/redmine/svnauthz; \
    echo "#developer=harry,sarry"               >> /etc/opt/redmine/svnauthz; \
    echo "#observer=john,greg"                  >> /etc/opt/redmine/svnauthz; \
    echo ""                                     >> /etc/opt/redmine/svnauthz; \
    echo "# 全てのプロジェクトに対する共通設定" >> /etc/opt/redmine/svnauthz; \
    echo "[/]"                                  >> /etc/opt/redmine/svnauthz; \
    echo "admin = rw"                           >> /etc/opt/redmine/svnauthz; \
    echo "* = rw"                               >> /etc/opt/redmine/svnauthz; \
    echo "guest = r"                            >> /etc/opt/redmine/svnauthz; \
    echo ""                                     >> /etc/opt/redmine/svnauthz; \
    echo "# サンプルプロジェクトに対する設定"   >> /etc/opt/redmine/svnauthz; \
    echo "[SampleProject:/]"                    >> /etc/opt/redmine/svnauthz; \
    echo "guest = rw"                           >> /etc/opt/redmine/svnauthz; \
    echo "#@developer = rw"                     >> /etc/opt/redmine/svnauthz; \
    echo "#@observer= r"                        >> /etc/opt/redmine/svnauthz; \
    echo ""                                     >> /etc/opt/redmine/svnauthz; \
    echo "# 特定のパスの設定"                   >> /etc/opt/redmine/svnauthz; \
    echo "#[SampleProject:/tags]"               >> /etc/opt/redmine/svnauthz; \
    echo "#* = r"                               >> /etc/opt/redmine/svnauthz; \
    echo "#admin = rw"                          >> /etc/opt/redmine/svnauthz



########################################  scm設定  ########################################


RUN mkdir -p $INSTALL_DIR/bin; \
    mkdir -p /var/opt/redmine/git /var/opt/redmine/svn /var/opt/redmine/maven


# scm-creator : create ${INSTALL_DIR}/config/scm.yml
RUN echo 'production:'                                         > ${INSTALL_DIR}/config/scm.yml; \
    echo '   auto_create: true'                               >> ${INSTALL_DIR}/config/scm.yml; \
    echo '   deny_delete: true'                               >> ${INSTALL_DIR}/config/scm.yml; \
    echo '   allow_add_local: true'                           >> ${INSTALL_DIR}/config/scm.yml; \
    echo '   post_create: ${INSTALL_DIR}/bin/scm-post-create' >> ${INSTALL_DIR}/config/scm.yml; \
    echo '   svn:'                                            >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     path: /var/opt/redmine/svn'                    >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     svnadmin: /usr/bin/svnadmin'                   >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     url: repos/svn'                                >> ${INSTALL_DIR}/config/scm.yml; \
    echo '   git:'                                            >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     path: /var/opt/redmine/git'                    >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     git: /usr/bin/git'                             >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     options: --bare '                              >> ${INSTALL_DIR}/config/scm.yml; \
    echo '     url: repos/git'                                >> ${INSTALL_DIR}/config/scm.yml


# scm-creator : create ${INSTALL_DIR}/bin/scm-post-create
RUN echo '#!/bin/sh'                                                            > ${INSTALL_DIR}/bin/scm-post-create; \
    echo ''                                                                    >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo 'case "$2" in'                                                        >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo ''                                                                    >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '  git)'                                                              >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    git --git-dir=$1 update-server-info'                             >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    echo "'                                                          >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '#!/bin/sh'                                                           >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '${INSTALL_DIR}/bin/sync-scm'                                         >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '" > $1/hooks/post-receive'                                           >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    chmod u+x $1/hooks/post-receive'                                 >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    mv $1/hooks/update.sample $1/hooks/update'                       >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    mv $1/hooks/post-update.sample $1/hooks/post-update'             >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    echo $1 | sed "s/.*\///" > $1/description'                       >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    git --git-dir=$1 config --bool hooks.allowunannotated true'      >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    git --git-dir=$1 config --bool receive.denyNonFastforwards true' >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    git --git-dir=$1 config --bool receive.denyDeletes true'         >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    git --git-dir=$1 config --bool core.quotepath false'             >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '  ;;'                                                                >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo ''                                                                    >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '  svn)'                                                              >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    echo "#!/bin/sh'                                                 >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '${INSTALL_DIR}/bin/sync-scm $1'                                      >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '" > $1/hooks/post-commit'                                            >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '    chmod u+x $1/hooks/post-commit'                                  >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo '  ;;'                                                                >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo ''                                                                    >> ${INSTALL_DIR}/bin/scm-post-create; \
    echo 'esac'                                                                >> ${INSTALL_DIR}/bin/scm-post-create


# scm-creator : create ${INSTALL_DIR}/bin/sync-scm
RUN echo '#!/bin/sh'                                                                                                                > ${INSTALL_DIR}/bin/sync-scm; \
    echo 'if [ "$1" != "" ]'                                                                                                       >> ${INSTALL_DIR}/bin/sync-scm; \
    echo 'then'                                                                                                                    >> ${INSTALL_DIR}/bin/sync-scm; \
    echo '    wget -q -O /dev/null http://localhost/sys/fetch_changesets?id=`echo $1 | sed "s/\/.*\/\([^\.]*\)\(\..*\)\?/\1/"`'    >> ${INSTALL_DIR}/bin/sync-scm; \
    echo 'else'                                                                                                                    >> ${INSTALL_DIR}/bin/sync-scm; \
    echo '    wget -q -O /dev/null http://localhost/sys/fetch_changesets?id=`echo $PWD | sed "s/\/.*\/\([^\.]*\)\(\..*\)\?/\1/"`'  >> ${INSTALL_DIR}/bin/sync-scm; \
    echo 'fi'                                                                                                                      >> ${INSTALL_DIR}/bin/sync-scm


# scm-creator : create ${INSTALL_DIR}/hooks/git/post-receive
RUN mkdir -p ${INSTALL_DIR}/hooks/git; \
    echo '#!/bin/sh'                    > ${INSTALL_DIR}/hooks/git/post-receive; \
    echo ''                            >> ${INSTALL_DIR}/hooks/git/post-receive; \
    echo '${INSTALL_DIR}/bin/sync-scm' >> ${INSTALL_DIR}/hooks/git/post-receive


# scm-creator : create ${INSTALL_DIR}/hooks/svn/post-commit
RUN mkdir -p ${INSTALL_DIR}/hooks/svn; \
    echo '#!/bin/sh'                          > ${INSTALL_DIR}/hooks/svn/post-commit; \
    echo ''                                  >> ${INSTALL_DIR}/hooks/svn/post-commit; \
    echo '/opt/redmine/bin/alm-sync-scm $@'  >> ${INSTALL_DIR}/hooks/svn/post-commit



########################################  [setting]apache  ########################################

ENV APACHE_USER=apache
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
RUN echo '<Location /jenkins>'                                        > /etc/httpd/conf.d/jenkins.conf; \
    echo '  Order allow,deny'                                        >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  Allow from all'                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo ''                                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  BrowserMatch "MSIE" AuthDigestEnableQueryStringHack=On'  >> /etc/httpd/conf.d/jenkins.conf; \
    echo ''                                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  ProxyPass        http://127.0.0.1:8080/jenkins'          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  ProxyPassReverse http://127.0.0.1:8080/jenkins'          >> /etc/httpd/conf.d/jenkins.conf; \
    echo ''                                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  RewriteEngine On'                                        >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  RewriteCond %{LA-U:REMOTE_USER} (.+)'                    >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  RewriteRule . - [E=RU:%1,NS]'                            >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  RequestHeader set X-Forwarded-User %{RU}e'               >> /etc/httpd/conf.d/jenkins.conf; \
    echo ''                                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLNoPasswd      Off'                              >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMYSQLEnable        On'                               >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLHost          localhost'                        >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLDB            redmine'                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLUser          redmine'                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLPassword      redmine'                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLUserTable     users'                            >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLNameField     login'                            >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLPasswordField hashed_password'                  >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLPwEncryption  sha1-rm'                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLSaltField     salt'                             >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthMySQLGroupField    groups'                           >> /etc/httpd/conf.d/jenkins.conf; \
    echo ''                                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthName "Redmine User"'                                 >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  AuthType Basic'                                          >> /etc/httpd/conf.d/jenkins.conf; \
    echo '  require  valid-user'                                     >> /etc/httpd/conf.d/jenkins.conf; \
    echo '</Location>'                                               >> /etc/httpd/conf.d/jenkins.conf


# edit sysconfig
RUN sed -i 's/JENKINS_ARGS=""/JENKINS_ARGS="--prefix=\/jenkins"/' /etc/sysconfig/jenkins


# get jenkins plugin-list
RUN mkdir -p /var/lib/jenkins/plugins; \
    chown jenkins.jenkins /var/lib/jenkins/plugins; \
    service jenkins start; \
    sleep 30; \
    wget -O $INSTALL_DIR/bin/jenkins-cli.jar http://localhost:8080/jenkins/jnlpJars/jenkins-cli.jar; \
    curl -L http://updates.jenkins-ci.org/update-center.json | sed '1d;$d' | curl -X POST -H 'Accept: application/json' -d @- http://localhost:8080/updateCenter/byId/default/postBack; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin reverse-proxy-auth-plugin; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin git; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin redmine; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ install-plugin dashboard-view; \
    mkdir -p /var/lib/jenkins; \
    echo '<?xml version="1.0" encoding="UTF-8"?>'                                                                                           > /var/lib/jenkins/config.xml; \
    echo '<hudson>'                                                                                                                        >> /var/lib/jenkins/config.xml; \
    echo '  <disabledAdministrativeMonitors>'                                                                                              >> /var/lib/jenkins/config.xml; \
    echo '    <string>hudson.diagnosis.ReverseProxySetupMonitor</string>'                                                                  >> /var/lib/jenkins/config.xml; \
    echo '  </disabledAdministrativeMonitors>'                                                                                             >> /var/lib/jenkins/config.xml; \
    echo '  <version>1.0</version>'                                                                                                        >> /var/lib/jenkins/config.xml; \
    echo '  <numExecutors>2</numExecutors>'                                                                                                >> /var/lib/jenkins/config.xml; \
    echo '  <mode>NORMAL</mode>'                                                                                                           >> /var/lib/jenkins/config.xml; \
    echo '  <useSecurity>true</useSecurity>'                                                                                               >> /var/lib/jenkins/config.xml; \
    echo '  <authorizationStrategy class="hudson.security.AuthorizationStrategy$Unsecured"/>'                                              >> /var/lib/jenkins/config.xml; \
    echo '  <!-- <securityRealm class="org.jenkinsci.plugins.reverse_proxy_auth.ReverseProxySecurityRealm" plugin="reverse-proxy-auth-plugin">' >> /var/lib/jenkins/config.xml; \
    echo '    <proxyTemplate/>'                                                                                                            >> /var/lib/jenkins/config.xml; \
    echo '    <authContext/>'                                                                                                              >> /var/lib/jenkins/config.xml; \
    echo '    <inhibitInferRootDN>false</inhibitInferRootDN>'                                                                              >> /var/lib/jenkins/config.xml; \
    echo '    <userSearchBase></userSearchBase>'                                                                                           >> /var/lib/jenkins/config.xml; \
    echo '    <userSearch>uid={0}</userSearch>'                                                                                            >> /var/lib/jenkins/config.xml; \
    echo '    <authorities/>'                                                                                                              >> /var/lib/jenkins/config.xml; \
    echo '    <forwardedUser>X-Forwarded-User</forwardedUser>'                                                                             >> /var/lib/jenkins/config.xml; \
    echo '    <headerGroups>X-Forwarded-Groups</headerGroups>'                                                                             >> /var/lib/jenkins/config.xml; \
    echo '    <headerGroupsDelimiter>|</headerGroupsDelimiter>'                                                                            >> /var/lib/jenkins/config.xml; \
    echo '  </securityRealm> -->'                                                                                                              >> /var/lib/jenkins/config.xml; \
    echo '  <projectNamingStrategy class="jenkins.model.ProjectNamingStrategy$DefaultProjectNamingStrategy"/>'                             >> /var/lib/jenkins/config.xml; \
    echo '  <workspaceDir>${ITEM_ROOTDIR}/workspace</workspaceDir>'                                                                        >> /var/lib/jenkins/config.xml; \
    echo '  <buildsDir>${ITEM_ROOTDIR}/builds</buildsDir>'                                                                                 >> /var/lib/jenkins/config.xml; \
    echo '  <markupFormatter class="hudson.markup.RawHtmlMarkupFormatter">'                                                                >> /var/lib/jenkins/config.xml; \
    echo '    <disableSyntaxHighlighting>false</disableSyntaxHighlighting>'                                                                >> /var/lib/jenkins/config.xml; \
    echo '  </markupFormatter>'                                                                                                            >> /var/lib/jenkins/config.xml; \
    echo '  <jdks/>'                                                                                                                       >> /var/lib/jenkins/config.xml; \
    echo '  <viewsTabBar class="hudson.views.DefaultViewsTabBar"/>'                                                                        >> /var/lib/jenkins/config.xml; \
    echo '  <myViewsTabBar class="hudson.views.DefaultMyViewsTabBar"/>'                                                                    >> /var/lib/jenkins/config.xml; \
    echo '  <clouds/>'                                                                                                                     >> /var/lib/jenkins/config.xml; \
    echo '  <slaves/>'                                                                                                                     >> /var/lib/jenkins/config.xml; \
    echo '  <scmCheckoutRetryCount>0</scmCheckoutRetryCount>'                                                                              >> /var/lib/jenkins/config.xml; \
    echo '  <views>'                                                                                                                       >> /var/lib/jenkins/config.xml; \
    echo '    <hudson.model.AllView>'                                                                                                      >> /var/lib/jenkins/config.xml; \
    echo '      <owner class="hudson" reference="../../.."/>'                                                                              >> /var/lib/jenkins/config.xml; \
    echo '      <name>すべて</name>'                                                                                                       >> /var/lib/jenkins/config.xml; \
    echo '      <filterExecutors>false</filterExecutors>'                                                                                  >> /var/lib/jenkins/config.xml; \
    echo '      <filterQueue>false</filterQueue>'                                                                                          >> /var/lib/jenkins/config.xml; \
    echo '      <properties class="hudson.model.View$PropertyList"/>'                                                                      >> /var/lib/jenkins/config.xml; \
    echo '    </hudson.model.AllView>'                                                                                                     >> /var/lib/jenkins/config.xml; \
    echo '  </views>'                                                                                                                      >> /var/lib/jenkins/config.xml; \
    echo '  <primaryView>すべて</primaryView>'                                                                                             >> /var/lib/jenkins/config.xml; \
    echo '  <slaveAgentPort>0</slaveAgentPort>'                                                                                            >> /var/lib/jenkins/config.xml; \
    echo '  <label></label>'                                                                                                               >> /var/lib/jenkins/config.xml; \
    echo '  <nodeProperties/>'                                                                                                             >> /var/lib/jenkins/config.xml; \
    echo '  <globalNodeProperties/>'                                                                                                       >> /var/lib/jenkins/config.xml; \
    echo '</hudson>'                                                                                                                       >> /var/lib/jenkins/config.xml; \
    java -jar $INSTALL_DIR/bin/jenkins-cli.jar -s http://localhost:8080/jenkins/ restart


########################################  after-setting  ########################################


CMD ["/bin/bash"]

