FROM		debian:bookworm

RUN		apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

RUN		mkdir -p /var/run/mysqld && chown -R mysql:mysql /var/run/mysqld && chmod 755 /var/run/mysqld
RUN		mkdir -p /var/log/mysql && chown -R mysql:mysql /var/log/mysql

COPY		conf/50-server.cnf	/etc/mysql/mariadb.conf.d/50-server.cnf
COPY		tools/init_db.sh	/usr/local/bin/init_db.sh
RUN		chmod +x /usr/local/bin/init_db.sh

EXPOSE		3306

ENTRYPOINT	["/usr/local/bin/init_db.sh"]