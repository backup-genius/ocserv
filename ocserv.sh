#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#set -o errexit  # 自动出错立即退出，不适用于交互式菜单；改成手动错误处理
set -o nounset
set -o pipefail

trap 'echo "${Error} 运行出错: $BASH_COMMAND"' ERR

#=================================================
#	System Required: Debian/Ubuntu
#	Description: ocserv AnyConnect
#	Version: 1.0.6
#	Author: Toyo, edited by GitHub someone
#	Blog: https://doub.io/vpnzy-7/
#=================================================
sh_ver="1.0.6"
file="/usr/local/sbin/ocserv"
conf_file="/etc/ocserv"
conf="/etc/ocserv/ocserv.conf"
passwd_file="/etc/ocserv/ocpasswd"
log_file="/tmp/ocserv.log"
ocserv_ver="1.4.1"
ocserv_download_base="https://www.infradead.org/ocserv/download"
# Original ocserv_ver = 0.11.8
PID_FILE="/var/run/ocserv.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	#bit=`uname -m`
}
check_installed_status(){
	[[ ! -e ${file} ]] && echo -e "${Error} ocserv 没有安装，请检查 !" && exit 1
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}
check_pid(){
	if [[ ! -e ${PID_FILE} ]]; then
		PID=""
	else
		PID=$(cat ${PID_FILE})
	fi
}
Get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}

Download_ocserv(){ 
	mkdir "ocserv" && cd "ocserv"
	wget "${ocserv_download_base}/ocserv-${ocserv_ver}.tar.xz"
	[[ ! -s "ocserv-${ocserv_ver}.tar.xz" ]] && echo -e "${Error} ocserv 源码文件下载失败 !" && rm -rf "ocserv/" && rm -rf "ocserv-${ocserv_ver}.tar.xz" && exit 1
	tar -xJf "ocserv-${ocserv_ver}.tar.xz" && cd "ocserv-${ocserv_ver}"
	./configure
	make
	make install
	cd .. && cd ..
	rm -rf ocserv/

	# Check if the installation was successful
	if [[ -e ${file} ]]; then
		# Ask the user which configuration file to use
		echo -e "请选择配置文件类型:\n2. 完整代理配置 除苹果 (all conf)"
		read -p "请输入数字 (2): " conf_choice

		# Set the config file source based on user input
		case $conf_choice in			
			2)
				conf_src="${SCRIPT_DIR}/ocserv-all.conf"
				;;
			*)
				echo -e "${Error} 无效的选择，请输入 2."
				exit 1
				;;
		esac

	# Create directory for config and get the chosen file
	mkdir -p "${conf_file}"
	if [[ -s "${conf_src}" ]]; then
		cp -f "${conf_src}" "${conf_file}/ocserv.conf"
	else
		# 从GitHub获取
		conf_src_github="https://raw.githubusercontent.com/backup-genius/ocserv/refs/heads/master/ocserv-all.conf"
		wget -O "${conf_file}/ocserv.conf" "$conf_src_github"
		[[ ! -s "${conf_file}/ocserv.conf" ]] && echo -e "${Error} 无法从GitHub下载配置文件 ${conf_src_github}" && rm -rf "${conf_file}" && return 1
	fi

	# Verify if the file exists and is valid
	[[ ! -s "${conf_file}/ocserv.conf" ]] && echo -e "${Error} ocserv 配置文件获取失败 !" && rm -rf "${conf_file}" && return 1
	else
		echo -e "${Error} ocserv 编译安装失败，请检查！" && exit 1
	fi
}


Service_ocserv(){
	if [[ ! -s "${SCRIPT_DIR}/ocserv_debian" ]]; then
		echo -e "${Error} 本地服务脚本不存在: ${SCRIPT_DIR}/ocserv_debian" && over
	fi
	cp -f "${SCRIPT_DIR}/ocserv_debian" /etc/init.d/ocserv
	chmod +x /etc/init.d/ocserv
	update-rc.d -f ocserv defaults
	echo -e "${Info} ocserv 服务 管理脚本下载完成 !"
}
rand(){
	min=10000
	max=$((60000-$min+1))
	num=$(date +%s%N)
	echo $(($num%$max+$min))
}
Generate_SSL(){
	lalala=$(rand)
	mkdir /tmp/ssl && cd /tmp/ssl
	echo -e 'cn = "'${lalala}'"
organization = "'${lalala}'"
serial = 1
expiration_days = 365
ca
signing_key
cert_signing_key
crl_signing_key' > ca.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(ca.tmpl) !" && over
	certtool --generate-privkey --outfile ca-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(ca-key.pem) !" && over
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(ca-cert.pem) !" && over
	
	Get_ip
	if [[ -z "$ip" ]]; then
		echo -e "${Error} 检测外网IP失败 !"
		read -e -p "请手动输入你的服务器外网IP:" ip
		[[ -z "${ip}" ]] && echo "取消..." && over
	fi
	echo -e 'cn = "'${ip}'"
organization = "'${lalala}'"
expiration_days = 365
signing_key
encryption_key
tls_www_server' > server.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(server.tmpl) !" && over
	certtool --generate-privkey --outfile server-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(server-key.pem) !" && over
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(server-cert.pem) !" && over
	
	mkdir -p /etc/ocserv/ssl
	mv ca-cert.pem /etc/ocserv/ssl/ca-cert.pem
	mv ca-key.pem /etc/ocserv/ssl/ca-key.pem
	mv server-cert.pem /etc/ocserv/ssl/server-cert.pem
	mv server-key.pem /etc/ocserv/ssl/server-key.pem
	cd .. && rm -rf /tmp/ssl/
}

Installation_dependency(){
	# Check if the VPS has TUN enabled
	[[ ! -e "/dev/net/tun" ]] && echo -e "${Error} 你的VPS没有开启TUN，请联系IDC或通过VPS控制面板打开TUN/TAP开关 !" && exit 1

	# Handle different distributions
	if [[ ${release} = "centos" ]]; then
		echo -e "${Error} 本脚本不支持 CentOS 系统 !" && exit 1
	else
		:
	fi

	apt-get update
	apt-get install vim net-tools iproute2 pkg-config build-essential libgnutls28-dev libwrap0-dev liblz4-dev libseccomp-dev libreadline-dev libnl-nf-3-dev libev-dev gnutls-bin ipcalc-ng -y
}

Ensure_ocserv_user(){
	if ! getent group ocserv >/dev/null; then
		groupadd --system ocserv
	fi
	if ! id -u ocserv >/dev/null 2>&1; then
		useradd --system --gid ocserv --home-dir /var/lib/ocserv --shell /usr/sbin/nologin ocserv
	fi
	mkdir -p /var/lib/ocserv
}

Apply_hardening_defaults(){
	[[ -e ${conf} ]] || return 0
	sed -i 's/^run-as-user = .*/run-as-user = ocserv/' ${conf}
	sed -i 's/^run-as-group = .*/run-as-group = ocserv/' ${conf}
}

Install_ocserv(){
	check_root
	[[ -e ${file} ]] && echo -e "${Error} ocserv 已安装，请检查 !" && return 1
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始下载/安装 配置文件..."
	Download_ocserv
	if [[ $? -ne 0 ]]; then
		echo -e "${Error} ocserv 下载/安装失败"
		return 1
	fi
	echo -e "${Info} 开始创建专用服务账号..."
	Ensure_ocserv_user
	echo -e "${Info} 开始应用安全默认配置..."
	Apply_hardening_defaults
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_ocserv
	echo -e "${Info} 开始自签SSL证书..."
	Generate_SSL
	echo -e "${Info} 开始设置账号配置..."
	if ! Read_config; then
		echo -e "${Error} 读取配置失败，停止安装"
		return 1
	fi
	if ! Set_Config; then
		echo -e "${Error} 设置配置失败"
		return 1
	fi
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加 iptables防火墙规则..."
	Add_iptables
	echo -e "${Info} 开始保存 iptables防火墙规则..."
	Save_iptables
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start_ocserv
	return 0
}
Start_ocserv(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ocserv 正在运行，请检查 !" && exit 1
	/etc/init.d/ocserv start
	sleep 2s
	check_pid
	[[ ! -z ${PID} ]] && View_Config
}
Stop_ocserv(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ocserv 没有运行，请检查 !" && exit 1
	/etc/init.d/ocserv stop
}
Restart_ocserv(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/ocserv stop
	sleep 3s
	/etc/init.d/ocserv start
	sleep 2s
	check_pid
	[[ ! -z ${PID} ]] && View_Config
}
Set_ocserv(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	vim ${conf}
	set_tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	set_udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	# Del_iptables
	sleep 1s
	Add_iptables
	sleep 1s
	Save_iptables
	echo "是否重启 ocserv ? (Y/n)"
	read -e -p "(默认: Y):" yn
	[[ -z ${yn} ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		Restart_ocserv
	fi
}
Set_username(){
	echo "请输入 要添加的VPN账号 用户名"
	read -e -p "(默认: admin):" username
	[[ -z "${username}" ]] && username="admin"
	echo && echo -e "	用户名 : ${Red_font_prefix}${username}${Font_color_suffix}" && echo
}
Set_passwd(){
	while true
	do
		echo "请输入 要添加的VPN账号 密码 (至少12位，包含字母和数字)"
		read -r -s -p "密码: " userpass
		echo
		if [[ ${#userpass} -lt 12 ]]; then
			echo -e "${Error} 密码长度至少12位"
			continue
		fi
		if [[ ! "${userpass}" =~ [A-Za-z] ]] || [[ ! "${userpass}" =~ [0-9] ]]; then
			echo -e "${Error} 密码必须同时包含字母和数字"
			continue
		fi
		break
	done
	echo && echo -e "	密码 : ${Red_font_prefix}${userpass}${Font_color_suffix}" && echo
}
Set_tcp_port(){
	while true
	do
	echo -e "请输入VPN服务端的TCP端口"
	read -e -p "(默认: 443):" set_tcp_port
	[[ -z "$set_tcp_port" ]] && set_tcp_port="443"
	echo $((${set_tcp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_tcp_port} -ge 1 ]] && [[ ${set_tcp_port} -le 65535 ]]; then
			echo && echo -e "	TCP端口 : ${Red_font_prefix}${set_tcp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_udp_port(){
	while true
	do
	echo -e "请输入VPN服务端的UDP端口"
	read -e -p "(默认: ${set_tcp_port}):" set_udp_port
	[[ -z "$set_udp_port" ]] && set_udp_port="${set_tcp_port}"
	echo $((${set_udp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_udp_port} -ge 1 ]] && [[ ${set_udp_port} -le 65535 ]]; then
			echo && echo -e "	TCP端口 : ${Red_font_prefix}${set_udp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_Config(){
	Set_username
	Set_passwd
	echo -e "${userpass}\n${userpass}"|ocpasswd -c ${passwd_file} ${username}
	Set_tcp_port
	Set_udp_port
	sed -i 's/tcp-port = '"$(echo ${tcp_port})"'/tcp-port = '"$(echo ${set_tcp_port})"'/g' ${conf}
	sed -i 's/udp-port = '"$(echo ${udp_port})"'/udp-port = '"$(echo ${set_udp_port})"'/g' ${conf}
}
Read_config(){
	if [[ ! -e ${conf} ]]; then
		echo -e "${Error} ocserv 配置文件不存在 ! 尝试从 GitHub 下载..."
		wget -q -O "${conf}" "https://raw.githubusercontent.com/backup-genius/ocserv/refs/heads/master/ocserv-all.conf"
		if [[ ! -s ${conf} ]]; then
			echo -e "${Error} 无法获取 ocserv 配置文件，检查网络或手动放置 ${conf}"
			return 1
		fi
	fi
	conf_text=$(grep -v '^#' ${conf})
	tcp_port=$(echo -e "${conf_text}"|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(echo -e "${conf_text}"|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	max_same_clients=$(echo -e "${conf_text}"|grep "max-same-clients ="|awk -F ' = ' '{print $NF}')
	max_clients=$(echo -e "${conf_text}"|grep "max-clients ="|awk -F ' = ' '{print $NF}')
	return 0
}
List_User(){
	[[ ! -e ${passwd_file} ]] && echo -e "${Error} ocserv 账号配置文件不存在 !" && exit 1
	User_text=$(cat ${passwd_file})
	if [[ ! -z ${User_text} ]]; then
		User_num=$(echo -e "${User_text}"|wc -l)
		user_list_all=""
		for((integer = 1; integer <= ${User_num}; integer++))
		do
			user_name=$(echo -e "${User_text}" | awk -F ':*:' '{print $1}' | sed -n "${integer}p")
			user_status=$(echo -e "${User_text}" | awk -F ':*:' '{print $NF}' | sed -n "${integer}p"|cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				user_status="禁用"
			else
				user_status="启用"
			fi
			user_list_all=${user_list_all}"用户名: "${user_name}" 账号状态: "${user_status}"\n"
		done
		echo && echo -e "用户总数 ${Green_font_prefix}"${User_num}"${Font_color_suffix}"
		echo -e ${user_list_all}
	fi
}
Add_User(){
	Set_username
	Set_passwd
	user_status=$(cat "${passwd_file}"|grep "${username}"':*:')
	[[ ! -z ${user_status} ]] && echo -e "${Error} 用户名已存在 ![ ${username} ]" && exit 1
	echo -e "${userpass}\n${userpass}"|ocpasswd -c ${passwd_file} ${username}
	user_status=$(cat "${passwd_file}"|grep "${username}"':*:')
	if [[ ! -z ${user_status} ]]; then
		echo -e "${Info} 账号添加成功 ![ ${username} ]"
	else
		echo -e "${Error} 账号添加失败 ![ ${username} ]" && exit 1
	fi
}
Del_User(){
	List_User
	[[ ${User_num} == 1 ]] && echo -e "${Error} 当前仅剩一个账号配置，无法删除 !" && exit 1
	echo -e "请输入要删除的VPN账号的用户名"
	read -e -p "(默认取消):" Del_username
	[[ -z "${Del_username}" ]] && echo "已取消..." && exit 1
	user_status=$(cat "${passwd_file}"|grep "${Del_username}"':*:')
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Del_username}]" && exit 1
	ocpasswd -c ${passwd_file} -d ${Del_username}
	user_status=$(cat "${passwd_file}"|grep "${Del_username}"':*:')
	if [[ -z ${user_status} ]]; then
		echo -e "${Info} 删除成功 ! [${Del_username}]"
	else
		echo -e "${Error} 删除失败 ! [${Del_username}]" && exit 1
	fi
}
Modify_User_disabled(){
	List_User
	echo -e "请输入要启用/禁用的VPN账号的用户名"
	read -e -p "(默认取消):" Modify_username
	[[ -z "${Modify_username}" ]] && echo "已取消..." && exit 1
	user_status=$(cat "${passwd_file}"|grep "${Modify_username}"':*:')
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Modify_username}]" && exit 1
	user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
	if [[ ${user_status} == '!' ]]; then
			ocpasswd -c ${passwd_file} -u ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} != '!' ]]; then
				echo -e "${Info} 启用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 启用失败 ! [${Modify_username}]" && exit 1
			fi
		else
			ocpasswd -c ${passwd_file} -l ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				echo -e "${Info} 禁用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 禁用失败 ! [${Modify_username}]" && exit 1
			fi
		fi
}
Set_Pass(){
	check_installed_status
	echo && echo -e " 你要做什么？
	
 ${Green_font_prefix} 0.${Font_color_suffix} 列出 账号配置
————————
 ${Green_font_prefix} 1.${Font_color_suffix} 添加 账号配置
 ${Green_font_prefix} 2.${Font_color_suffix} 删除 账号配置
————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启用/禁用 账号配置
 
 注意：添加/修改/删除 账号配置后，VPN服务端会实时读取，无需重启服务端 !" && echo
	read -e -p "(默认: 取消):" set_num
	[[ -z "${set_num}" ]] && echo "已取消..." && exit 1
	if [[ ${set_num} == "0" ]]; then
		List_User
	elif [[ ${set_num} == "1" ]]; then
		Add_User
	elif [[ ${set_num} == "2" ]]; then
		Del_User
	elif [[ ${set_num} == "3" ]]; then
		Modify_User_disabled
	else
		echo -e "${Error} 请输入正确的数字[1-3]" && exit 1
	fi
}
View_Config(){
	Get_ip
	Read_config
	clear && echo "===================================================" && echo
	echo -e " AnyConnect 配置信息：" && echo
	echo -e " I  P\t\t  : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " TCP端口\t  : ${Green_font_prefix}${tcp_port}${Font_color_suffix}"
	echo -e " UDP端口\t  : ${Green_font_prefix}${udp_port}${Font_color_suffix}"
	echo -e " 单用户设备数限制 : ${Green_font_prefix}${max_same_clients}${Font_color_suffix}"
	echo -e " 总用户设备数限制 : ${Green_font_prefix}${max_clients}${Font_color_suffix}"
	echo -e "\n 客户端链接请填写 : ${Green_font_prefix}${ip}:${tcp_port}${Font_color_suffix}"
	echo && echo "==================================================="
}
View_Log(){
	[[ ! -e ${log_file} ]] && echo -e "${Error} ocserv 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${log_file}${Font_color_suffix} 命令。" && echo
	tail -f ${log_file}
}
Uninstall_ocserv(){
	check_installed_status "un"
	echo "确定要卸载 ocserv ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill ${PID} && rm -f ${PID_FILE}
		Read_config
		Del_iptables
		Save_iptables
		update-rc.d -f ocserv remove
		rm -rf /etc/init.d/ocserv
		rm -rf "${conf_file}"
		rm -rf "${log_file}"
		cd '/usr/local/bin' && rm -f occtl
		rm -f ocpasswd
		cd '/usr/local/bin' && rm -f ocserv-fw
		cd '/usr/local/sbin' && rm -f ocserv
		cd '/usr/local/share/man/man8' && rm -f ocserv.8
		rm -f ocpasswd.8
		rm -f occtl.8
		echo && echo "ocserv 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}
over(){
	update-rc.d -f ocserv remove
	rm -rf /etc/init.d/ocserv
	rm -rf "${conf_file}"
	rm -rf "${log_file}"
	cd '/usr/local/bin' && rm -f occtl
	rm -f ocpasswd
	cd '/usr/local/bin' && rm -f ocserv-fw
	cd '/usr/local/sbin' && rm -f ocserv
	cd '/usr/local/share/man/man8' && rm -f ocserv.8
	rm -f ocpasswd.8
	rm -f occtl.8
	echo && echo "安装过程错误，ocserv 卸载完成 !" && echo
}

Fix_Iptables(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	conf_text=$(cat ${conf}|grep -v '#')
	set_tcp_port=$(echo -e "${conf_text}"|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	set_udp_port=$(echo -e "${conf_text}"|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加 iptables防火墙规则..."
	Del_iptables
	Add_iptables
	echo -e "${Info} 开始保存 iptables防火墙规则..."
	Save_iptables
}

Add_iptables(){
	iptables -C INPUT -m state --state NEW -m tcp -p tcp --dport ${set_tcp_port} -j ACCEPT 2>/dev/null || iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${set_tcp_port} -j ACCEPT
	iptables -C INPUT -m state --state NEW -m udp -p udp --dport ${set_udp_port} -j ACCEPT 2>/dev/null || iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${set_udp_port} -j ACCEPT
}
Del_iptables(){
	iptables -C INPUT -m state --state NEW -m tcp -p tcp --dport ${tcp_port} -j ACCEPT 2>/dev/null && iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${tcp_port} -j ACCEPT || true
	iptables -C INPUT -m state --state NEW -m udp -p udp --dport ${udp_port} -j ACCEPT 2>/dev/null && iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${udp_port} -j ACCEPT || true
}
Save_iptables(){
	iptables-save > /etc/iptables.up.rules
}
Set_iptables(){
	if ! grep -q '^net.ipv4.ip_forward=1$' /etc/sysctl.conf; then
		echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	fi
 	#echo -e "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
  	
	sysctl -p
	Network_card=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
	if [[ -z ${Network_card} ]]; then
		echo -e "${Error} 自动检测网卡失败"
		ip -o link show
		read -e -p "请手动输入你的网卡名:" Network_card
		[[ -z "${Network_card}" ]] && echo "取消..." && exit 1
	fi
	iptables -t nat -C POSTROUTING -o ${Network_card} -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o ${Network_card} -j MASQUERADE
	
	iptables-save > /etc/iptables.up.rules
	echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
	chmod +x /etc/network/if-pre-up.d/iptables
}
Update_Shell(){
	echo -e "${Tip} 已禁用在线自更新（安全考虑）。请通过版本控制拉取仓库更新。"
	exit 0
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1

while true; do
  echo && echo -e " ocserv 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- original: Toyo | doub.io/vpnzy-7 --
  -- edited by github someone --
  
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
————————————
 ${Green_font_prefix}3.${Font_color_suffix} 启动 ocserv
 ${Green_font_prefix}4.${Font_color_suffix} 停止 ocserv
 ${Green_font_prefix}5.${Font_color_suffix} 重启 ocserv
————————————
 ${Green_font_prefix}6.${Font_color_suffix} 设置 账号配置
 ${Green_font_prefix}7.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix}8.${Font_color_suffix} 修改 配置文件
 ${Green_font_prefix}9.${Font_color_suffix} 查看 日志信息
————————————
 ${Green_font_prefix}10.${Font_color_suffix} 修复 iptables
 ${Green_font_prefix}q.${Font_color_suffix} 退出脚本
————————————" && echo

  if [[ -e ${file} ]]; then
    check_pid
    if [[ ! -z "${PID}" ]]; then
      echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
    else
      echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
    fi
  else
    echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
  fi
  echo
  read -e -p " 请输入数字 [0-10/q]:" num
  case "$num" in
    0)
      if ! Update_Shell; then
        echo "${Error} 升级脚本失败"
      fi
      ;;
    1)
      if ! Install_ocserv; then
        echo "${Error} 安装 ocserv 失败，请检查日志或终端输出"
      fi
      ;;
    2)
      if ! Uninstall_ocserv; then
        echo "${Error} 卸载 ocserv 失败"
      fi
      ;;
    3)
      if ! Start_ocserv; then
        echo "${Error} 启动 ocserv 失败"
      fi
      ;;
    4)
      if ! Stop_ocserv; then
        echo "${Error} 停止 ocserv 失败"
      fi
      ;;
    5)
      if ! Restart_ocserv; then
        echo "${Error} 重启 ocserv 失败"
      fi
      ;;
    6)
      if ! Set_Pass; then
        echo "${Error} 设置账号配置失败"
      fi
      ;;
    7)
      if ! View_Config; then
        echo "${Error} 查看配置信息失败"
      fi
      ;;
    8)
      if ! Set_ocserv; then
        echo "${Error} 修改配置文件失败"
      fi
      ;;
    9)
      if ! View_Log; then
        echo "${Error} 查看日志失败"
      fi
      ;;
    10)
      if ! Fix_Iptables; then
        echo "${Error} 修复 iptables 失败"
      fi
      ;;
    q|Q)
      echo "退出脚本"
      break
      ;;
    *)
      echo "请输入正确数字 [0-10/q]"
      ;;
  esac

done
