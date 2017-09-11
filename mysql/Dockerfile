FROM mysql:5.7

MAINTAINER Artem Dolobanko <dolobanko@gmail.com>

ENV PACKAGE percona-xtrabackup-23

RUN wget https://repo.percona.com/apt/percona-release_0.1-4.$(lsb_release -sc)_all.deb && \
    percona-release_0.1-4.$(lsb_release -sc)_all.deb && \
    apt-get update && \
    apt-get install -y $PACKAGE cron

 RUN touch /var/log/cron.log

 RUN mkdir -p /backup/backups

 RUN (crontab -l ; echo "0 0 */3 * * sh -c 'exec innobackupex --host="$MYSQL_PORT_3306_TCP_ADDR" --port="$MYSQL_PORT_3306_TCP_PORT" --user=root --password="$MYSQL_ENV_MYSQL_ROOT_PASSWORD" /backup/backups' >> /var/log/cron.log") | crontab

 RUN (crontab -l ; echo "0 1 */3 * * sh -c 'find /backup/backups -mtime +14 -exec rm {}\;' >> /var/log/cron.log") | crontab

 VOLUME ["/backup/xtrabackup"]
