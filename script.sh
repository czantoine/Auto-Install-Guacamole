VER="9.0.71"

sudo apt update

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
