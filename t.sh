#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author: dylanbai8
#	Dscription: cloud_torrent_onekey
#====================================================

#定义文字颜色
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#定义提示信息
Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

source /etc/os-release

#脚本欢迎语
v2ray_hello(){
	echo -e "${OK} ${GreenBG} 你正在执行 cloud_torrent_onekey 一键安装脚本 ${Font}"
}

#检测root权限
is_root(){
	if [ `id -u` == 0 ]
		then echo -e "${OK} ${GreenBG} 当前用户是root用户，开始安装流程 ${Font} "
		sleep 3
	else
		echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}"
		exit 1
	fi
}

#检测系统版本
check_system(){
	VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

	if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
		INS="yum"
	elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
		INS="apt"
	elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font}"
		INS="apt"
	else
		echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
		exit 1
	fi
}

#检测安装完成或失败
judge(){
	if [[ $? -eq 0 ]];then
		echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
		sleep 1
	else
		echo -e "${Error} ${RedBG} $1 失败${Font}"
		exit 1
	fi
}

#设定 端口
port_alterid_set(){
	echo ""
	echo -e "${Info} ${GreenBG} 请输入端口（默认:8080） ${Font}"
	stty erase '^H' && read -p "请输入：" port
	[[ -z ${port} ]] && port="8080"
}

#强制清除可能残余的http服务 关闭防火墙 更新源
apache_uninstall(){
	echo -e "${OK} ${GreenBG} 正在强制清理可能残余的http服务 ${Font}"
	if [[ "${ID}" == "centos" ]];then

	systemctl disable httpd >/dev/null 2>&1
	systemctl stop httpd >/dev/null 2>&1
	yum erase httpd httpd-tools apr apr-util -y >/dev/null 2>&1

	systemctl disable firewalld >/dev/null 2>&1
	systemctl stop firewalld >/dev/null 2>&1

	echo -e "${OK} ${GreenBG} 正在更新源 请稍后 …… ${Font}"

	yum -y update

	else

	systemctl disable apache2 >/dev/null 2>&1
	systemctl stop apache2 >/dev/null 2>&1
	apt purge apache2 -y >/dev/null 2>&1

	echo -e "${OK} ${GreenBG} 正在更新源 请稍后 …… ${Font}"

	apt -y update

	fi

	systemctl disable cloud-torrent >/dev/null 2>&1
	systemctl stop cloud-torrent >/dev/null 2>&1

	systemctl disable rinetd-bbr >/dev/null 2>&1
	systemctl stop rinetd-bbr >/dev/null 2>&1

	rm -rf /usr/local/bin/cloud-torrent /usr/local/bin/cloud-torrent.json /etc/systemd/system/cloud-torrent.service >/dev/null 2>&1
	rm -rf /usr/bin/rinetd-bbr /etc/rinetd-bbr.conf /etc/systemd/system/rinetd-bbr.service >/dev/null 2>&1
}

#安装各种依赖工具
dependency_install(){
	for CMD in iptables grep cut xargs systemctl ip awk
	do
		if ! type -p ${CMD}; then
			echo -e "${Error} ${RedBG} 缺少必要依赖 脚本终止安装 ${Font}"
			exit 1
		fi
	done
	${INS} install curl lsof -y
	judge "安装 curl lsof 依赖"
}

#检测端口是否占用
port_exist_check(){
	if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
		echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
		sleep 1
	else
		echo -e "${Error} ${RedBG} 检测到 $1 端口被占用，以下为 $1 端口占用信息 ${Font}"
		lsof -i:"$1"
		echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
		sleep 5
		lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
		echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
		sleep 1
	fi
}

#安装cloud-torrent并添加自启动
cloud_torrent_install(){
	curl https://i.jpillora.com/cloud-torrent! | bash
	judge "cloud-torrent 安装"

	cat <<EOF > /etc/systemd/system/cloud-torrent.service
[Unit]
Description=cloud-torrent

[Service]
WorkingDirectory=/root/
ExecStart=/usr/local/bin/cloud-torrent --port ${port} --config-path /usr/local/bin/cloud-torrent.json --title "Cloud Torrent"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
	judge "cloud-torrent 自启动配置"

	systemctl enable cloud-torrent >/dev/null 2>&1
	systemctl start cloud-torrent
	judge "cloud-torrent 启动"
}

#安装bbr端口加速
rinetdbbr_install(){
	export RINET_URL="https://github.com/dylanbai8/cloud_torrent_onekey/raw/master/bbr/rinetd_bbr_powered"
	IFACE=$(ip -4 addr | awk '{if ($1 ~ /inet/ && $NF ~ /^[ve]/) {a=$NF}} END{print a}')

	curl -L "${RINET_URL}" >/usr/bin/rinetd-bbr
	chmod +x /usr/bin/rinetd-bbr
	judge "rinetd-bbr 安装"

	cat <<EOF >> /etc/rinetd-bbr.conf
0.0.0.0 ${port} 0.0.0.0 ${port}
EOF

	cat <<EOF > /etc/systemd/system/rinetd-bbr.service
[Unit]
Description=rinetd with bbr
[Service]
ExecStart=/usr/bin/rinetd-bbr -f -c /etc/rinetd-bbr.conf raw ${IFACE}
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
	judge "rinetd-bbr 自启动配置"

	systemctl enable rinetd-bbr >/dev/null 2>&1
	systemctl start rinetd-bbr
	judge "rinetd-bbr 启动"
}

#安装成功 展示地址
show_information(){
	ip=`curl -4 ip.sb`
	clear
	echo ""
	echo -e "${Info} ${GreenBG} 安装 Cloud Torrent 成功 ${Font}"
	echo -e "----------------------------------------------------------"
	echo -e "${Green} 地址：${Font} http://${ip}:${port}"
	echo -e "----------------------------------------------------------"
}

#脚本执行流程
main(){
	is_root
	check_system
	v2ray_hello
	port_alterid_set
	apache_uninstall
	dependency_install
	port_exist_check ${port}
	cloud_torrent_install
	rinetdbbr_install
	show_information
}

onekey_uninstall(){
if [[ -e /usr/local/bin/cloud-torrent ]]; then
	systemctl disable cloud-torrent >/dev/null 2>&1
	systemctl stop cloud-torrent >/dev/null 2>&1
	judge "cloud-torrent 卸载"

	systemctl disable rinetd-bbr >/dev/null 2>&1
	systemctl stop rinetd-bbr >/dev/null 2>&1
	judge "rinetd-bbr 卸载"

	rm -rf /usr/local/bin/cloud-torrent /usr/local/bin/cloud-torrent.json /etc/systemd/system/cloud-torrent.service >/dev/null 2>&1
	rm -rf /usr/bin/rinetd-bbr /etc/rinetd-bbr.conf /etc/systemd/system/rinetd-bbr.service >/dev/null 2>&1
	judge "清除残余文件"
else
	echo -e "${Error} ${RedBG} Cloud Torrent 未安装或者已卸载 请勿重复执行 ${Font}"
fi
}

add_password(){
	systemctl disable cloud-torrent >/dev/null 2>&1
	systemctl stop cloud-torrent >/dev/null 2>&1
	rm -rf /etc/systemd/system/cloud-torrent.service >/dev/null 2>&1

	echo ""
	echo -e "${Info} ${GreenBG} 请输入端口（默认:8080） ${Font}"
	stty erase '^H' && read -p "请输入：" port
	[[ -z ${port} ]] && port="8080"
	echo -e "${Info} ${GreenBG} 请输入用户名（默认:user） ${Font}"
	stty erase '^H' && read -p "请输入：" user
	[[ -z ${user} ]] && user="user"
	echo -e "${Info} ${GreenBG} 请输入密码（默认:password） ${Font}"
	stty erase '^H' && read -p "请输入：" password
	[[ -z ${password} ]] && password="password"

	cat <<EOF > /etc/systemd/system/cloud-torrent.service
[Unit]
Description=cloud-torrent

[Service]
WorkingDirectory=/root/
ExecStart=/usr/local/bin/cloud-torrent --port ${port} --config-path /usr/local/bin/cloud-torrent.json --title "Cloud Torrent" --auth "${user}:${password}"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
	judge "cloud-torrent 添加/修改 用户名、密码、端口"

	systemctl enable cloud-torrent >/dev/null 2>&1
	systemctl start cloud-torrent
	judge "cloud-torrent 启动"

	ip=`curl -4 ip.sb`
	clear
	echo ""
	echo -e "${Info} ${GreenBG} 配置 Cloud Torrent 成功 ${Font}"
	echo -e "----------------------------------------------------------"
	echo -e "${Green} 地址：${Font} http://${ip}:${port}"
	echo -e "${Green} 用户名：${Font} ${user} ${Green} 密码：${Font} ${password}"
	echo -e "----------------------------------------------------------"
}

#Bash执行选项
if [[ $# > 0 ]];then
	key="$1"
	case $key in
		-u|--onekey_uninstall)
		onekey_uninstall
		;;
		-p|--add_password)
		add_password
		;;
	esac
else
	main
fi
