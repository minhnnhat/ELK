#!/bin/bash
sudo -n true
if [ $? -ne 0 ]
then
	echo "This script requires user to have passwordless sudo access"
	exit
fi

function add_file_config_deb {
    name_service=$1
    sudo mv /etc/${name_service}/filebeat.yml /etc/${name_service}/filebeat.bak
    sudo cat >/etc/${name_service}/filebeat.yml <<EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/auth.log
    - /var/log/syslog
    - /var/log/faillog
    - /var/log/boot.log
    - /var/log/kernel.log
### ( NỘI DUNG THÊM CHO ĐƯỜNG DẪN FIREWALL và SERVICES TRONG /VAR/LOG/[NAME_SERVICE]/*.log)
#    - /var/log/ufw.log
#    - /var/log/firewalld
#    - /var/log/nginx/*.log

processors:
- drop_fields:
    fields: ["type", "beat", "prospector", "input", "offset"]

### Có thể thay đổi ip và port cho phù hợp với vị trí máy chủ đang chạy logstash
output.logstash:
  hosts: ["118.70.194.13:2514"]
#  hosts: ["172.30.206.252:2514"]
EOF
    version=$(cat /etc/os-release | grep -i 'VERSION_ID' | sed 's/[^0-9]*//g')
    if [ $version -ge 1604 ]
    then
        echo 'Run systemd'
        sudo systemctl daemon-reload
        sudo systemctl enable ${name_service}
        sudo systemctl start ${name_service}
    else
        echo 'Run init'
        sudo /etc/init.d/${name_service} start
    fi
}

function add_file_config_rpm {
    name_service=$1
    sudo mv /etc/${name_service}/filebeat.yml /etc/${name_service}/filebeat.bak
    sudo cat >/etc/${name_service}/filebeat.yml <<EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/secure
    - /var/log/message
    - /var/log/boot.log
    - /var/log/yum.log
    - /var/log/cron
### ( NOI DUNG THEM CHO ĐƯỜNG DẪN FIREWALL và SERVICES TRONG /VAR/LOG/[NAME_SERVICE]/*.log)
#   Log kernel
#    - /var/log/kern
#   Log firewalld trên centos 7
#    - /var/log/firewalld
#   Log iptables tren centos 6
#    - /var/log/iptables
#    - /var/log/nginx/*.log
processors:
- drop_fields:
    fields: ["type", "beat", "prospector", "input", "offset"]

### Có thể thay đổi ip và port cho phù hợp với vị trí máy chủ đang chạy logstash
output.logstash:
  hosts: ["118.70.194.13:2514"]
#  hosts: ["172.30.206.252:2514"]
EOF
    version=$(rpm -q --queryformat '%{VERSION}' centos-release)
    if [ $version -eq 7 ]
    then
        echo "Centos 7"
        sudo systemctl daemon-reload
        sudo systemctl enable ${name_service}
        sudo systemctl start ${name_service}
    else
        echo "Centos version old"
        sudo /etc/init.d/${name_service} start
    fi
}

function add_service {
    name_service1=$1
    name_service2=$2
	sudo cp -R /etc/${name_service1} /etc/${name_service2}/
	mkdir -p /var/log/${name_service2}/
	cat >/lib/systemd/system/${name_service2}.service<<EOF
[Unit]
Description=filebeat-01
Documentation=https://www.elastic.co/guide/en/beats/filebeat/current/index.html
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/share/filebeat/bin/filebeat -c /etc/filebeat-01/filebeat.yml -path.home /usr/share/filebeat -path.config /etc/filebeat-01 -path.data /var/lib/filebeat -path.logs /var/log/filebeat-01
Restart=always

[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
	sudo systemctl enable ${name_service2}
	sudo systemctl start ${name_service2}

}

function rpm_filebeat {
    	name_service=$1
	sudo wget --directory-prefix=/opt/ https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.3.2-x86_64.rpm
	sudo rpm -vi /opt/filebeat-6.3.2-x86_64.rpm
    	add_file_config_rpm filebeat
}

function deb_filebeat {
	sudo wget --directory-prefix=/opt/ https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.3.2-amd64.deb
	sudo dpkg -i /opt/filebeat-6.3.2-amd64.deb
    	add_file_config_deb filebeat
}

function add_service_rpm {
    version=$(rpm -q --queryformat '%{VERSION}' centos-release)
    if [ $version -eq 7 ]
    then
        add_service filebeat filebeat-01
    	add_file_config_rpm filebeat-01
    else
        echo "use file manual Add_service_filebeat-01.txt"
#        add_initd filebeat filebeat-01
#        add_file_config_rpm filebeat-01
    fi
}

function add_service_deb {
    version=$(cat /etc/os-release | grep -i 'VERSION_ID' | sed 's/[^0-9]*//g')
    if [ $version -ge 1604 ]
    then
        add_service filebeat filebeat-01
    	add_file_config_deb filebeat-01
    else
        echo "use file manual Add_service_filebeat-01.txt"
#        add_initd filebeat filebeat-01
#        add_file_config_deb filebeat-01
    fi
}

if [ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]
then
	echo " It's a Debian based system"
#	filebeat -version
#	if [ $? -eq 0 ]
	if [ "$(grep -Ei 'filebeat' $`find /etc/* -name 'filebeat'` -s -R -n)" ]
	then
		add_service_deb
	else
        	deb_filebeat
	fi
elif [ "$(grep -Ei 'fedora|redhat|centos' /etc/*release)" ]
then
	echo "It's a RedHat based system."
#	filebeat -version
#	if [ $? -eq 0 ]
	if [ "$(grep -Ei 'filebeat' $`find /etc/* -name 'filebeat'` -s -R -n)" ]
	then
		add_service_rpm
	else
        	rpm_filebeat
	fi
else
	echo "This script doesn't support filebeat installation on this OS."
fi