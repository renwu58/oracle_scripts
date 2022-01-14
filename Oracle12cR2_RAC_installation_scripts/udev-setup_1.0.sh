#/bin/bash
#########################################
#
#  Oracle 12c R2 RAC安装ASM磁盘配置脚本
#  Jeffy<renwu58@hotmail.com>
#
#  请基于自己实际情况修改磁盘映射关系
#
#########################################

lsscsi --scsi_id |awk 'BEGIN { 
   linknames["/dev/sda"]="asmdisk/OCRDISK01" 
   linknames["/dev/sdb"]="asmdisk/OCRDISK02" 
   linknames["/dev/sdc"]="asmdisk/OCRDISK03" 
   linknames["/dev/sdd"]="asmdisk/FRADISK01" 
   linknames["/dev/sde"]="asmdisk/DATADISK001" 
} 
{ if($2=="disk" && linknames[$(NF-1)]!=""){ 
    split($(NF-1),devs,"/",seps);
    printf("KERNEL==\"%s\", ENV{DEVTYPE}==\"disk\", SUBSYSTEM==\"block\", PROGRAM==\"/usr/lib/udev/scsi_id -g -u -d %s\",RESULT==\"%s\", SYMLINK+=\"%s\", OWNER=\"grid\",GROUP=\"asmadmin\", MODE=\"0660\"\n", devs[3], $(NF-1),$NF,linknames[$(NF-1)]); 
    } 
}' >>/etc/udev/rules.d/99-oracle-asmdevices.rules


systemctl restart systemd-udevd.service
/sbin/udevadm control --reload-rules
/sbin/udevadm trigger --type=devices --action=add
/sbin/udevadm trigger --type=devices --action=change
sleep 3
