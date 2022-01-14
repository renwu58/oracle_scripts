#/bin/bash
#########################################
#
#  Oracle 12c R2 RAC安装用户创建脚本
#  Jeffy<renwu58@hotmail.com>
#
#  请基于自己实际情况修改用户密码
#
#########################################

grid_passwd=grid123
oracle_passwd=oracle123


# Create group
groupadd -g 1000 oinstall
groupadd -g 1001 dba
groupadd -g 1002 oper 
groupadd -g 1010 asmadmin
groupadd -g 1011 asmdba
groupadd -g 1012 asmoper
groupadd -g 1013 backupdba
groupadd -g 1014 dgdba
groupadd -g 1015 kmdba
groupadd -g 1016 racdba


#Create user
useradd -u 1000 -g oinstall -G asmoper,asmadmin,asmdba,oper -m -d /home/grid --comment "Grid Infrastructure Owner" grid
useradd -u 1001 -g oinstall -G dba,oper,asmdba,backupdba,dgdba,kmdba,racdba -m -d /home/oracle --comment "Oracle Software Owner" oracle

# Password
echo "$grid_passwd" | passwd --stdin grid
echo "$oracle_passwd" | passwd --stdin oracle

# Create working directory
mkdir -p /u01/app/grid  
mkdir -p /u01/app/12.2.0.1/grid    
mkdir -p /u01/app/oracle/product/12.2.0.1/db
mkdir -p /u01/oracle/grid
mkdir -p /u01/oracle/database


# Change the owner and group of working directory
chown -R oracle:oinstall /u01
chown -R grid:oinstall /u01/app
chown -R oracle:oinstall /u01/app/oracle
chown -R grid:oinstall /u01/oracle/grid
chown -R oracle:oinstall /u01/oracle/database
chmod -R 775 /u01
