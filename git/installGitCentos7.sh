# Установить GIT на CentOS 7

sudo yum update -y
sudo yum groupinstall "Development Tools" -y
sudo yum install gettext-devel openssl-devel perl-CPAN perl-devel zlib-devel -y
curl -LJ0 https://github.com/git/git/archive/v2.29.2.tar.gz --output git.tar.gz
tar -zxf git.tar.gz
cd git-2.29.2
make configure
./configure --prefix=/usr/local
sudo make install
