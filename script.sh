#!/bin/bash

VER="9.0.71"
IP="3.208.17.184"

sudo apt update
cd
sudo apt-get install build-essential make -y
sudo apt install -y gcc nano vim curl wget g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev \
libavcodec-dev  libavformat-dev libavutil-dev libswscale-dev build-essential libpango1.0-dev libssh2-1-dev libvncserver-dev \
libtelnet-dev libpulse-dev libvorbis-dev libwebp-dev

sudo add-apt-repository ppa:remmina-ppa-team/remmina-next-daily
sudo apt update
sudo apt install freerdp2-dev freerdp2-x11 -y

wget https://www.openssl.org/source/openssl-1.1.1l.tar.gz -P ~
sudo tar -xzf openssl-1.1.1l.tar.gz
cd ~/openssl-1.1.1l
sudo ./config
sudo make
sudo make install
sudo cp /usr/local/bin/openssl /usr/bin
sudo ldconfig

sudo apt install openjdk-17-jdk -y

sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat
cd 
sudo wget https://downloads.apache.org/tomcat/tomcat-9/v${VER}/bin/apache-tomcat-${VER}.tar.gz -P ~
sudo mkdir -p /opt/tomcat
sudo tar -xzf apache-tomcat-${VER}.tar.gz -C /opt/tomcat/
sudo mv /opt/tomcat/apache-tomcat-${VER} /opt/tomcat/tomcatapp
sudo chown -R tomcat: /opt/tomcat
sudo find /opt/tomcat/tomcatapp/bin/ -type f -iname "*.sh" -exec chmod +x {} \;

sudo bash -c 'cat >> /etc/systemd/system/tomcat.service' << EOF
[Unit]
Description=Tomcat 9 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat/tomcatapp"
Environment="CATALINA_HOME=/opt/tomcat/tomcatapp"
Environment="CATALINA_PID=/opt/tomcat/tomcatapp/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/tomcatapp/bin/startup.sh
ExecStop=/opt/tomcat/tomcatapp/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

sudo systemctl enable --now tomcat

wget https://downloads.apache.org/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz -P ~
tar xzf ~/guacamole-server-1.4.0.tar.gz
cd ~/guacamole-server-1.4.0
sudo ./configure --disable-guacenc --with-init-dir=/etc/init.d
sudo make
sudo make install
sudo ldconfig
sudo systemctl daemon-reload
sudo systemctl start guacd
sudo systemctl enable guacd
sudo mkdir /etc/guacamole
wget https://downloads.apache.org/guacamole/1.4.0/binary/guacamole-1.4.0.war -P ~
sudo mv ~/guacamole-1.4.0.war /etc/guacamole/guacamole.war
sudo ln -s /etc/guacamole/guacamole.war /opt/tomcat/tomcatapp/webapps/
echo "GUACAMOLE_HOME=/etc/guacamole" | sudo tee -a /etc/default/tomcat
echo "export GUACAMOLE_HOME=/etc/guacamole" | sudo tee -a /etc/profile

sudo bash -c 'cat >> /etc/guacamole/guacamole.properties' << EOF
guacd-hostname: localhost
guacd-port:     4822
user-mapping:   /etc/guacamole/user-mapping.xml
auth-provider:   net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
EOF

sudo ln -s /etc/guacamole /opt/tomcat/tomcatapp/.guacamole
sudo chown -R tomcat: /opt/tomcat


echo -n GoodStrongPassword | openssl md5

echo -n AdminStrongPassword | openssl md5



sudo bash -c 'cat >> /etc/guacamole/user-mapping.xml' << EOF
<user-mapping>

    <!-- Per-user authentication and config information -->

    <!-- A user using md5 to hash the password
         guacadmin user and its md5 hashed password below is used to 
             login to Guacamole Web UI-->
    <!-- FIRST USER -->
    <authorize 
            username="GeeksAdmin"
            password="2df81f5bfb14c621dbfd98e0d08c2f35"
            encoding="md5">

        <!-- First authorized Remote connection -->
        <connection name="RHEL 7 Maipo">
            <protocol>ssh</protocol>
            <param name="hostname">172.25.169.26</param>
            <param name="port">22</param>
        </connection>

        <!-- Second authorized remote connection -->
        <connection name="Windows Server 2019">
            <protocol>rdp</protocol>
            <param name="hostname">10.10.10.5</param>
            <param name="port">3389</param>
            <param name="username">tech</param>
            <param name="ignore-cert">true</param>
        </connection>

    </authorize>

    <!-- SECOND USER -->

    <authorize 
            username="Tux"
            password="53bdac1400db24248d8b6cf9fcf93dc6"
            encoding="md5">


        <!-- First authorized remote connection -->
        <connection name="Windows Server 2019">
            <protocol>rdp</protocol>
            <param name="hostname">10.10.10.5</param>
            <param name="port">3389</param>
            <param name="username">tech</param>
            <param name="ignore-cert">true</param>
        </connection>
        <!-- Second authorized Remote connection -->
        <connection name="RHEL 7 Maipo">
            <protocol>ssh</protocol>
            <param name="hostname">172.25.169.26</param>
            <param name="port">22</param>
        </connection>

    </authorize>

</user-mapping>
EOF

sudo systemctl restart tomcat guacd

sudo apt-get install nginx -y
sudo systemctl enable nginx
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/guacamole-selfsigned.key -out /etc/ssl/certs/guacamole-selfsigned.crt

sudo bash -c 'cat >> /etc/nginx/sites-available/nginx-guacamole-ssl' << EOF
server {
	listen 80;
	server_name $IP;
EOF
echo '	return 301 https://$host$request_uri;'| sudo tee -a /etc/nginx/sites-available/nginx-guacamole-ssl 
sudo bash -c 'cat >> /etc/nginx/sites-available/nginx-guacamole-ssl' << EOF
}
server {
	listen 443 ssl;
	server_name guacamole.example.com;

	root /var/www/html;

	index index.html index.htm index.nginx-debian.html;
    
    ssl_certificate /etc/ssl/certs/guacamole-selfsigned.crt;
	ssl_certificate_key /etc/ssl/private/guacamole-selfsigned.key;

	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers on; 
	ssl_dhparam /etc/nginx/dhparam.pem;
	ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
	ssl_ecdh_curve secp384r1;
	ssl_session_timeout  10m;
	ssl_session_cache shared:SSL:10m;
	resolver $IP 8.8.8.8 valid=300s;
	resolver_timeout 5s; 
	add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
	add_header X-Frame-Options DENY;
	add_header X-Content-Type-Options nosniff;
	add_header X-XSS-Protection "1; mode=block";

	access_log  /var/log/nginx/guac_access.log;
	error_log  /var/log/nginx/guac_error.log;

	location / {
		    proxy_pass http://$IP:8080/guacamole/;
		    proxy_buffering off;
		    proxy_http_version 1.1;
EOF
echo '	    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'| sudo tee -a /etc/nginx/sites-available/nginx-guacamole-ssl 
echo '	    proxy_set_header Upgrade $http_upgrade;'| sudo tee -a /etc/nginx/sites-available/nginx-guacamole-ssl 
echo '	    proxy_set_header Connection $http_connection;'| sudo tee -a /etc/nginx/sites-available/nginx-guacamole-ssl 
echo '	    proxy_cookie_path /guacamole/ /;'| sudo tee -a /etc/nginx/sites-available/nginx-guacamole-ssl 
sudo bash -c 'cat >> /etc/nginx/sites-available/nginx-guacamole-ssl' << EOF
	}

}
EOF

sudo openssl dhparam -dsaparam -out /etc/nginx/dhparam.pem 4096
sudo ln -s /etc/nginx/sites-available/nginx-guacamole-ssl /etc/nginx/sites-enabled/
sudo systemctl restart nginx
