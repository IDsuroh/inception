FROM	debian:bookworm

RUN	apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*

RUN	mkdir -p /etc/nginx/ssl

COPY	conf/nginx.conf		/etc/nginx/nginx.conf
COPY	tools/generate_ssl.sh	/usr/local/bin/

RUN	chmod +x /usr/local/bin/*.sh

EXPOSE	443

ENTRYPOINT	["/usr/local/bin/generate_ssl.sh"]
