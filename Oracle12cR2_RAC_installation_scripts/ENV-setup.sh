#/bin/bash
#########################################
#
#  Oracle 12c R2 RAC安装脚本
#  Jeffy<renwu58@hotmail.com>
#
#  请基于自己实际情况修改一下配置
#
#########################################

rac1_public_ip=10.30.53.57
rac2_public_ip=10.30.53.58
rac1_private_ip=10.30.41.3
rac2_private_ip=10.30.41.4
rac1_VIP=10.30.53.114
rac2_VIP=10.30.53.115
rac_scan_ip=10.30.53.116
rac_scan_name=rac-scan
hostname1=rac1
hostname2=rac2
ntp_server_ip=10.30.252.8
IP=`ip a |grep 'eth0$' |awk '{print $2}' |awk -F '/' '{print $1}'`
grid_passwd=grid123
oracle_passwd=oracle123

##########################################

# Modify the /etc/hosts
cat >> /etc/hosts <<EOF
#Public IP
$rac1_public_ip $hostname1
$rac2_public_ip $hostname2
#Private IP
$rac1_private_ip        pri-$hostname1
$rac2_private_ip        pri-$hostname2
#VIP
$rac1_VIP       $hostname1-vip
$rac2_VIP       $hostname2-vip
#Scan-IP
$rac_scan_ip    $rac_scan_name
EOF

# Modify the hostname
if [ $IP == $rac1_public_ip ];then
  hostnamectl set-hostname $hostname1
fi

if [ $IP == $rac2_public_ip ];then
  hostnamectl set-hostname $hostname2
fi

#Configure ntp
yum -y install ntp
sed -i 's/^server/#&/' /etc/ntp.conf
sed -i "/server 3.centos/a\server $ntp_server_ip iburst" /etc/ntp.conf
systemctl start ntpd.service
systemctl enable ntpd.service

echo "SYNC_HWCLOCK=yes">>/etc/sysconfig/ntpd
# -x 表示确保系统时间不会发生跳变
echo 'OPTIONS="-x"' >>/etc/sysconfig/ntpd


# Setting the timezone
timedatectl status
timedatectl set-timezone Africa/Luanda


# Stop firewall
systemctl stop firewalld
systemctl disable firewalld

# Redhat Linux 7 need stop avahi-daemon service, 
# if not iwhen install GI the Prerequisite checks will have warning, 
# the error code: PRVG-1360
if [[ -f "/etc/systemd/system/dbus-org.freedesktop.Avahi.service" ]]; then
    systemctl stop avahi-dnsconfd
    systemctl stop avahi-daemon
    systemctl disable avahi-dnsconfd
    systemctl disable avahi-daemon
fi

# Removed file for network rules and deleted UUID and HWADDR from adapter configuration files
# This is required if the VMs is cloned or using the same template created
rm -f /etc/udev/rules.d/70-persistent-net.rules
sed -i -e '/HWADDR/d' -e '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth[0-2]

# Disable selinux
sed -i '/^SELINUX=/ c\SELINUX=disabled' /etc/selinux/config
setenforce 0

# Configure the ENV of grid and oracle
if [ $IP == $rac1_public_ip ];then
cat >> /home/grid/.bash_profile << EOF
export ORACLE_SID=+ASM1
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/12.2.0.1/grid
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export THREADS_FLAG=native
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

cat >> /home/oracle/.bash_profile << EOF
export ORACLE_SID=rac1
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib
export ORACLE_UNQNAME=rac
export ORACLE_TERM=xterm
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

cat >> /root/.bash_profile << EOF
export GRID_HOME=/u01/app/12.2.0.1/grid
export ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db
export PATH=\$GRID_HOME/bin:\$GRID_HOME/OPatch:\$ORACLE_HOME/bin:\$PATH
EOF


fi

if [ $IP == $rac2_public_ip ];then
cat >> /home/grid/.bash_profile << EOF
export ORACLE_SID=+ASM2
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/12.2.0.1/grid
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export THREADS_FLAG=native
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

cat >> /home/oracle/.bash_profile << EOF
export ORACLE_SID=rac2
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib
export ORACLE_UNQNAME=rac
export ORACLE_TERM=xterm
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
export NLS_DATE_FORMAT="yyyy-mm-dd HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=\$ORACLE_HOME/bin:\$PATH
EOF

cat >> /root/.bash_profile << EOF
export GRID_HOME=/u01/app/12.2.0.1/grid
export ORACLE_HOME=/u01/app/oracle/product/12.2.0.1/db
export PATH=\$GRID_HOME/bin:\$GRID_HOME/OPatch:\$ORACLE_HOME/bin:\$PATH
EOF

fi

# Configure mutual trust
yum -y install expect
su -l grid -c  "ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa"
su -l grid -c /usr/bin/expect <<-EOF
set timeout 10
spawn ssh-copy-id -i /home/grid/.ssh/id_rsa.pub $rac1_public_ip 
expect { 
        "yes/no" { send "yes\r"; exp_continue }
        "password:" { send "$grid_passwd\r" }
        }
        expect eof
spawn ssh-copy-id -i /home/grid/.ssh/id_rsa.pub $hostname1
expect "yes/no" { send "yes\r" }
expect eof

spawn ssh-copy-id -i /home/grid/.ssh/id_rsa.pub $rac2_public_ip 
expect { 
        "yes/no" { send "yes\r"; exp_continue }
        "password:" { send "$grid_passwd\r" }
        }
        expect eof
spawn ssh-copy-id -i /home/grid/.ssh/id_rsa.pub $hostname2
expect "yes/no" { send "yes\r" }
expect eof
EOF

su -l oracle -c  "ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa"
su -l oracle -c /usr/bin/expect <<-EOF
set timeout 10
spawn ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub $rac1_public_ip 
expect { 
        "yes/no" { send "yes\r"; exp_continue }
        "password:" { send "$oracle_passwd\r" }
        }
        expect eof
spawn ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub $hostname1
expect "yes/no" { send "yes\r" }
expect eof

spawn ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub $rac2_public_ip 
expect { 
        "yes/no" { send "yes\r"; exp_continue }
        "password:" { send "$oracle_passwd\r" }
        }
        expect eof
spawn ssh-copy-id -i /home/oracle/.ssh/id_rsa.pub $hostname2
expect "yes/no" { send "yes\r" }
expect eof
EOF

# Configure the /dev/shm
echo 'tmpfs /dev/shm tmpfs defaults,size=16G 0 0' >> /etc/fstab
mount -o remount /dev/shm


# Create swap
# 基于规则，如果内存1-2GB, 设置为内存的1.5倍
# 如果内存为2-16GB, 设置和内存一样大小
# 如果内存超过16GB,统一设置为20GB

makeSwap(){
  mkdir /swap
  dd if=/dev/zero of=/swap/swapfile bs=${1}M count=1024
  sleep 3
  chmod 600 /swap/swapfile
  mkswap -f /swap/swapfile
  echo "/swap/swapfile    swap   swap      defaults       0 0" >>/etc/fstab
  swapon /swap/swapfile
}

# totalMemGB=$(free -g|grep Mem|tr -s [:space:]|cut -d" "  -f 2)
# currentSwapGB=$(swapon --show=SIZE --noheadings|tr -d [:alpha:])
# if [ $totalMemGB > 2 && $totalMemGB < 16 ]; then
#   makeSwap $totalMemGB
# fi

# if [ $totalMemGB > 16 ]; then
#   makeSwap 20
# fi

# Configure DNS server
echo "nameserver 10.30.53.30" >>/etc/resolv.conf
echo "search minjustica.lab" >>/etc/resolv.conf

# Configure the network
echo "NOZEROCONF=yes" >> /etc/sysconfig/network

# Configure /etc/pam.d/login
echo "session    required     pam_limits.so" >> /etc/pam.d/login

# Configure limits.conf
cat >> /etc/security/limits.conf <<EOF
oracle soft nproc 65536
oracle hard nproc 65536
oracle soft nofile 65536
oracle hard nofile 65536
oracle soft stack 65536
oracle hard stack 65536
oracle soft memlock 7357407
oracle hard memlock 7357407
grid soft nproc 65536
grid hard nproc 65536
grid soft nofile 65536
grid hard nofile 65536
grid soft stack 65536
grid hard stack 65536
EOF

# Configure kernel parameters
# kernel.shmmax = physical memory * 70% (byte) = 8*7%*1024*1024*1024
# kernel.sem 如果客户单个数据库需要支持的process数超过250
cat  >> /etc/sysctl.conf << EOF
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 10485760
kernel.shmmax = 6012954214
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.ipv4.ipfrag_high_thresh = 16777216
net.ipv4.ipfrag_low_thresh = 15728640
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
vm.min_free_kbytes= 524288
EOF
sysctl -p

# Install dependency packages
yum -y install binutils*  compat-libstdc++-33*  elfutils-libelf*  gcc*  glibc*  ksh*  libaio*  libgcc* libstdc*  make*  sysstat*  unixODBC*  libaio-devel*  glibc-devel libaio libaio-devel libstdc++-devel unixODBC-devel compat-libcap1*  compat-libcap1  expat* ksh libaio-devel xterm libXext libXtst libX11 libXau libxcb libXi smartmontools nfs-utils net-tools unzip xorg-x11-xauth

# Check the pachages installed or not
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libgcc libstdc++ libstdc++-devel libaio libaio-devel libXext libXtst libX11 libXau libxcb libXi make sysstat smartmontools nfs-utils net-tools unzip xorg-x11-xauth |grep "not installed"
