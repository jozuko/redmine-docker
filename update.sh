#!/bin/bash

# redmine DB data
if [ ! -f /var/lib/mysql/initialized ]
then
  cd / && tar xzf /opt/redmine/initdatas/db.tar.gz
  if [ -n "${REDMINE_HOST}" ]
  then
    /etc/init.d/mysqld start
    sleep 10
    echo "insert into settings (name, value, updated_on) value ('host_name', '${REDMINE_HOST}', current_timestamp)" > /root/temp.sql
    mysql -u redmine -predmine -D redmine < /root/temp.sql
  fi
elif [ "`cat /opt/redmine/initialized`" != "`cat /var/lib/mysql/initialized`" ]
then
  echo "update DB ..."
  cd /opt/redmine
  bundle exec rake db:migrate RAILS_ENV=production
  bundle exec rake redmine:plugins:migrate RAILS_ENV=production
  bundle exec rake tmp:cache:clear RAILS_ENV=production
  bundle exec rake tmp:sessions:clear RAILS_ENV=production
  cp -p /opt/redmine/initialized /var/lib/mysql/
  echo "...done"
fi

# attachement files
if [ ! -f /opt/redmine/files/initialized ]
then
  cd / && tar xzf /opt/redmine/initdatas/files.tar.gz
fi

# redmine repo
if [ ! -f /var/opt/redmine/initialized ]
then
  cd / && tar xzf /opt/redmine/initdatas/repo.tar.gz
  if [ "${SMTP_ENABLE}" = "y" ]
  then
    echo "default:
    email_delivery:" > ${INSTALL_DIR}/config/configuration.yml

    if [ -n "${SMTP_METHOD}" ]
    then
      echo "    delivery_method: :${SMTP_METHOD}" >> ${INSTALL_DIR}/config/configuration.yml
    fi

      echo "    smtp_settings:" >> ${INSTALL_DIR}/config/configuration.yml

    if [ -n "${SMTP_STARTTLS}" ]
    then
      echo "      enable_starttls_auto: ${SMTP_STARTTLS}" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_HOST}" ]
    then
      echo "      address: \"${SMTP_HOST}\"" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_PORT}" ]
    then
      echo "      port: ${SMTP_PORT}" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_DOMAIN}" ]
    then
      echo "      domain: \"${SMTP_DOMAIN}\"" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_AUTHENTICATION}" ]
    then
      echo "      authentication: :${SMTP_AUTHENTICATION}" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_USER}" ]
    then
      echo "      user_name: \"${SMTP_USER}\"" >> ${INSTALL_DIR}/config/configuration.yml
    fi

    if [ -n "${SMTP_PASS}" ]
    then
      echo "      password: \"${SMTP_PASS}\"" >> ${INSTALL_DIR}/config/configuration.yml
    fi
  fi
fi

# user-add
if [ -n "${ROOT_PASSWORD}" ]
then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

if [ -n "${USER}" -a -n "${USER_PASSWORD}" ]
then
  useradd $USER
  echo "${USER}:${USER_PASSWORD}" | chpasswd
  sed -i -e "s/Defaults *requiretty/# Defaults requiretty/" /etc/sudoers
  echo "${USER} ALL=(ALL) ALL" > /etc/sudoers.d/${USER}
  chmod 440 /etc/sudoers.d/$USER
fi

# setup-timezone
if [ -n "${LOCALTIME}" -a -n "${TIMEZONE}" ]
then
  mv /etc/localtime /etc/localtime.org; \
  cp /usr/share/zoneinfo/${LOCALTIME} /etc/localtime; \
  sed -i "s/^ZONE/#ZONE/g" /etc/sysconfig/clock; \
  sed -i "s/^UTC/#UTC/g" /etc/sysconfig/clock; \
  echo "ZONE=\"${TIMEZONE}\"" >> /etc/sysconfig/clock; \
  echo "UTC=\"False\"" >> /etc/sysconfig/clock
fi

# unset ENV
unset ROOT_PASSWORD
unset USER
unset USER_PASSWORD
unset LOCALTIME
unset TIMEZONE
unset REDMINE_HOST
unset SMTP_ENABLE
unset SMTP_METHOD
unset SMTP_STARTTLS
unset SMTP_HOST
unset SMTP_PORT
unset SMTP_DOMAIN
unset SMTP_AUTHENTICATION
unset SMTP_USER
unset SMTP_PASS

# apache start
/usr/sbin/httpd -k stop
/usr/sbin/httpd -D FOREGROUND

