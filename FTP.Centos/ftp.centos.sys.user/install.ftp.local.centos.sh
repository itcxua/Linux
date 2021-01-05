#!/bin/sh

echo "#====   FTP-Server   ====#"

# Установить FTP-сервер?
while true; do
read -e -p "Installed FTP-Server now or later (y/n)? " rsn
  case $rsn in
    [Yy]* ) break;;
    [Nn]* ) exit;
  esac
done

InstallFTPServSYSTEMuser()
{
sleep 10
#= схема с сис.пользователям =#

##================ ≠≠≠ ================
## VARIABLE
DATA=$(date +%Y%m%d-%H%M%S);
LOGFILE='/var/log/vsftpd.log'
VSFTPD_CONF='/etc/vsftpd/vsftpd.conf'
VSFTPD_PAM='/etc/pam.d/vsftpd'



##================ ≠≠≠ ================
# обновления системы и Устанавливаем vsftpd:
yum update -y && yum install vsftpd -y

##================ ≠≠≠ ================
##=== Переходим к настройке ===
# схему работы ftp сервера с системными пользователями.
# Пользователю root разрешаю ходить по всему серверу.
# Всем остальным пользователям только в свои домашние директории.
# Анонимных пользователей отключаю.
# Очистим каталог /etc/vsftpd, нам ничего не нужно из того,

# BACKUP VSFTPD каталога и очистка /etc/vsftpd/
tar czvf /etc/vsftpd.$DATA.tar.gz /etc/vsftpd && rm -rf /etc/vsftpd/*

##================ ≠≠≠ ================
## конфиг сервера /etc/vsftpd/vsftpd.conf
cat > $VSFTPD_CONF <<EOF
##================ ≠≠≠ ================
##          ===== CONFIG =====
##          ==| local user |==
##================ ≠≠≠ ================

# Запуск сервера в режиме службы
listen=YES

# Работа в фоновом режиме
background=YES

# Имя pam сервиса для vsftpd
pam_service_name=vsftpd

# Входящие соединения контроллируются через tcp_wrappers
tcp_wrappers=YES

# Запрещает подключение анонимных пользователей
anonymous_enable=NO

# Каталог, куда будут попадать анонимные пользователи, если они разрешены
#anon_root=/ftp

# Разрешает вход для локальных пользователей
local_enable=YES

# Разрешены команды на запись и изменение
write_enable=YES

# Указывает исходящим с сервера соединениям использовать 20-й порт
connect_from_port_20=YES

# Логирование всех действий на сервере
xferlog_enable=YES

# Путь к лог-файлу
xferlog_file=/var/log/vsftpd.log

# Включение специальных ftp команд, некоторые клиенты без этого могут зависать
async_abor_enable=YES

# Локальные пользователи по-умолчанию не могут выходить за пределы своего домашнего каталога
chroot_local_user=YES

# Разрешить список пользователей, которые могут выходить за пределы домашнего каталога
chroot_list_enable=YES

# Список пользователей, которым разрешен выход из домашнего каталога
chroot_list_file=/etc/vsftpd/chroot_list

# Разрешить запись в корень chroot каталога пользователя
allow_writeable_chroot=YES

# Контроль доступа к серверу через отдельный список пользователей
userlist_enable=YES

# Файл со списками разрешенных к подключению пользователей
userlist_file=/etc/vsftpd/user_list

# Пользователь будет отклонен, если его нет в user_list
userlist_deny=NO

# Директория с настройками пользователей
user_config_dir=/etc/vsftpd/users

# Показывать файлы, начинающиеся с точки
force_dot_files=YES

# Маска прав доступа к создаваемым файлам
local_umask=022

# Порты для пассивного режима работы
pasv_min_port=49000
pasv_max_port=55000
EOF

##================ ≠≠≠ ================
# Добавим пользователя ftp в систему:
# echo 'New User name: '; read USERNAME
USERNAME="ftpuser"
PASSWORD="ftpuser"
# echo 'New Password : '; read PASSWORD
userdel -f /sbin/nologin ftpuser
useradd -s /sbin/nologin ftpuser
passwd ftpuser ftpuser

# Пользователя создаем без оболочки. Тут сразу можно указать в качестве домашней директории необходимый каталог, в котором будет работать пользователь. Пользователь будет создан со стандартным домашним каталогом в /home, но при работе по ftp он будет направлен в другой каталог, который мы ему укажем через файл пользовательских настроек vsftpd. пользователь с оболочкой /sbin/nologin не может подключаться по ftp. Связано это с тем, что идет проверка оболочки, а ее нет в файле /etc/shells.


## отключАЕМ проверку оболочки в настройках pam для vsftpd. в  файле /etc/pam.d/vsftpd.
## Закомментируем строку: auth required pam_shells.so
#sed -i 's/^auth required .*/#auth required pam_shells.so/g' /etc/pam.d/vsftpd

##================ ≠≠≠ ================
## пересоздаем файл /etc/pam.d/vsftpd
cat $VSFTPD_PAM > $VSFTPD_PAM.$DATA.bac
cat > $VSFTPD_PAM <<EOF
#%PAM-1.0
session    optional pam_keyinit.so  force     revoke
auth       required pam_listfile.so item=user sense=deny file=/etc/vsftpd/ftpusers onerr=succeed
# auth       required pam_shells.so
auth       include  password-auth
account    include  password-auth
session    required pam_loginuid.so
session    include  password-auth
EOF

##================ ≠≠≠ ================
# каталог настроек пользователей:
FTP_DIRCONF='/etc/vsftpd/users'
if [[ ! -e $FTP_DIRCONF ]];
  then
    mkdir -p /etc/vsftpd/users
      elif [[ ! -d $FTP_DIRCONF ]];
  then
    echo "$FTP_DIRCONF exists, but is not a dir" 1>&2
    rm -rf $FTP_DIRCONF && mkdir $FTP_DIRCONF;
fi


##================ ≠≠≠ ================
# В каталоге можно будет создать файлы с именами пользователей
# Cозд. файл с польз ftpuser и укажем домашний каталог:
touch /etc/vsftpd/users/ftpuser
echo "local_root=/ftp/ftpuser/" >> "/etc/vsftpd/users/ftpuser"

# создать каталог и назнач. ему владельца:
mkdir /ftp && chmod 0777 /ftp
mkdir /ftp/ftpuser && chown ftpuser. /ftp/ftpuser/

# Список, разрешен выход за Домашний каталог:
touch /etc/vsftpd/chroot_list

# Добавляем туда рута:
echo 'root' >> /etc/vsftpd/chroot_list

##================ ≠≠≠ ================
# Список разрешенн доступ к FTP:
touch /etc/vsftpd/user_list
echo 'root' >> /etc/vsftpd/user_list && echo 'ftpuser' >> /etc/vsftpd/user_list
# Этим списком мы можем ограничить доступ к ftp серверу системных пользователей, которым не нужно.

# файл логов:
touch $LOGFILE && chmod 600 $LOGFILE

##================ ≠≠≠ ================
# Добавляем vsftpd в автозагрузку и запускаем:
systemctl enable vsftpd
systemctl start vsftpd
systemctl status vsftpd

# Проверяем, запустился ли он:
netstat -tulnp | grep vsftpd

exit
}
