mkdir -p git/release
cd git/release
wget https://github.com/git/git/archive/v2.0.0.tar.gz
tar -zxf v2.0.0.tar.gz
cd git-2.0.0
yum install autoconf gcc perl make -y
make configure
./configure --prefix=/usr
make all doc info

