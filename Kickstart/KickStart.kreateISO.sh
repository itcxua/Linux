
# ReBuild Centos7 with KS.cfg
##=====================================
PROJECTDIR=/home/Project/Centos7KS
ISODIR=/mnt/iso
WORKDIR=/home/Project/Centos7KS/centos
DOWNDIR=/home/Download/centos/7.8.2003/isos/x86_64/
CENTOSMIN="CentOS-7-x86_64-Minimal-2003.iso"
WEBCENTOSMIN="http://mirror.mirohost.net/centos/7.8.2003/isos/x86_64/CentOS-7-x86_64-Minimal-2003.iso"


##=====================================
yum install wget nano mkisofs -y

mkdir -p $DOWNDIR
cd $DOWNDIR
wget $WEBCENTOSMIN
sleep 5

mkdir -p $ISODIR
mount $DOWNDIR/$CENTOSMIN $ISODIR/

sleep 5
mkdir -p $WORKDIR
cp -rp $ISODIR/* $WORKDIR/

##=====================================
touch $PROJECTDIR/minimal.ks.cfg
KONF_KS=$PROJECTDIR/minimal.ks.cfg

cat > $KONF_KS <<-EOF
###
EOF

##=====================================

#cat ~/minimal.ks.cfg > $WORKDIR/ks.cfg


##=====================================
## isolinux
##
touch $PROJECTDIR/isolinux.cfg
KONF_ISOLINUX=$PROJECTDIR/isolinux.cfg

cat > $KONF_ISOLINUX <<-EOF

label auto
menu label ^Auto install CentOS 7
kernel vmlinuz
append  initrd=initrd.img inst.ks=cdrom:/dev/cdrom:/ks.cfg

label autolan
menu label ^Lan Auto install CentOS7
kernel vmlinuz
append initrd=initrd.img inst.ks=http://192.168.1.15/ks.cfg

EOF

##=====================================

#cat ~/minimal.ks.cfg > $WORKDIR/ks.cfg


#cp $WORKDIR/isolinux/isolinux.cfg /home/Project/Centos7KS/isolinux.cfg
#nano /home/isolinux.cfg

# cp /home/Project/Centos7KS/isolinux.cfg $WORKDIR/isolinux/isolinux.cfg


##=======================================
# создаем образ CentOS 7 x86_64
cd $WORKDIR/
# mkisofs -o /home/centos-cust.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V 'OEMDRV' -boot-load-size 4 -boot-info-table -R -J -v -T .

