#!/bin/sh

echo "#====   FTP в CentOS 7   ====#"
#= схема с сис.пользователям =#

##==============≠==============
## VARIABLE
DATA=$(date +%Y%m%d-%H%M%S);
LOGFILE='/var/log/vsftpd.log'
VSFTPD_CONF='/etc/vsftpd/vsftpd.conf'
VSFTPD_PAM='/etc/pam.d/vsftpd'


##==============≠==============
# обновления системы:
yum update -y
# Устанавливаем vsftpd:
yum install vsftpd -y

##==============≠==============
##=== Переходим к настройке ===
# схему работы ftp сервера с системными пользователями.
# Пользователю root разрешаю ходить по всему серверу.
# Всем остальным пользователям только в свои домашние директории.
# Анонимных пользователей отключаю.
# Очистим каталог /etc/vsftpd, нам ничего не нужно из того,

# BACKUP VSFTPD DIR
tar czvf /etc/vsftpd.$DATA.tar.gz /etc/vsftpd
rm -rf /etc/vsftpd/*

  ##==============≠==============
  # конфиг сервера /etc/vsftpd/vsftpd.conf
cat > $VSFTPD_CONF <<EOF
################################
##    ===== CONFIG =====
##    ==| local user |==
################################

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

##==============≠==============
# Добавим пользователя ftp в систему:
# echo 'New User name: '; read USERNAME
USERNAME="ftpuser"
PASSWORD="ftpuser"
# echo 'New Password : '; read PASSWORD
userdel -f /sbin/nologin ftpuser
useradd -s /sbin/nologin ftpuser
passwd ftpuser ftpuser

# Пользователя создаем без оболочки. Тут сразу можно указать в качестве домашней директории необходимый каталог, в котором будет работать пользователь. Я специально этого не делаю, чтобы продемонстрировать работу пользовательских настроек в отдельном файле. Пользователь будет создан со стандартным домашним каталогом в /home, но при работе по ftp он будет направлен в другой каталог, который мы ему укажем через файл пользовательских настроек vsftpd.
# Здесь стоит обратить внимание на один момент.
# Начиная с какой-то версии то ли vsftpd или Centos пользователь с оболочкой /sbin/nologin не может подключаться по ftp. Связано это с тем, что идет проверка оболочки, а ее нет в файле /etc/shells. Я не пробовал ее туда добавлять, так как не понимаю до конца назначение этого файла. Я предлагаю просто отключить проверку оболочки в настройках pam для vsftpd. в  файле /etc/pam.d/vsftpd. Нужно закомментировать следующую строку:
#auth required pam_shells.so
#sed -i 's/^auth required .*/#auth required pam_shells.so/g' /etc/pam.d/vsftpd

# пересоздаем
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

# каталог настроек пользователей:
mkdir -p /etc/vsftpd/users

# В каталоге можно будет создать файлы с именами пользователей
# Cозд. файл с польз ftpuser и укажем домашний каталог:
touch /etc/vsftpd/users/ftpuser
echo 'local_root=/ftp/ftpuser/' >> '/etc/vsftpd/users/ftpuser'

# создать каталог и назнач. ему владельца:
mkdir /ftp && chmod 0777 /ftp
mkdir /ftp/ftpuser && chown ftpuser. /ftp/ftpuser/

# Список, разрешен выход за HOME:
touch /etc/vsftpd/chroot_list

# Добавляем туда рута:
echo 'root' >> /etc/vsftpd/chroot_list

# Создать файл со списком пользователей ftp.

# Список разрешенн доступ к FTP:
touch /etc/vsftpd/user_list
echo 'root' >> /etc/vsftpd/user_list && echo 'ftpuser' >> /etc/vsftpd/user_list
# Этим списком мы можем ограничить доступ к ftp серверу системных пользователей, которым не нужно.

# файл логов:
touch $LOGFILE && chmod 600 $LOGFILE

# Добавляем vsftpd в автозагрузку и запускаем:
systemctl enable vsftpd
systemctl start vsftpd
systemctl status vsftpd

# Проверяем, запустился ли он:
netstat -tulnp | grep vsftpd

exit
