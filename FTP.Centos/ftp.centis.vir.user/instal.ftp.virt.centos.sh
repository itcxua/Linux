##====install.ftp.virt centos.sh====####

##==== vsftpd VIRTUAL USER ====##
DATA = $(date +%Y%m%d-%H%M%S);
ADD_VIRTUSER = '/etc/vsftpd/add_virt_user.sh'

# Рассмотрим вариант, когда пользователи ftp сервера не должны пересекаться с локальными. В данном примере будут работать только виртуальные пользователи. Я мельком проверил, можно ли настроить и тех и других, оказалось, что можно. Но там надо аккуратно с правами разбираться и со списками разрешенных пользователей. Я решил, что не буду описывать эту ситуацию, так как не очень представлю, когда она может пригодиться. Если кому-то надо, то на базе этой статьи он сам сможет разобраться.

# авторизовать вирт. польз.установим доп.пакет compat-db:
yum install compat-db -y

# На всякий случай сохраните оригинальный pam.d файл, если захотите снова вернуться к системным пользователям:
cp /etc/pam.d/vsftpd /etc/pam.d/vsftpd."$DATA".orig

# Нужно изменить pam файл /etc/pam.d/vsftpd, приведя его к следующему виду:

#mcedit /etc/pam.d/vsftpd
### =========================
# пересоздаем
cat /etc/pam.d/vsftpd > /etc/pam.d/vsftpd.bac
cat > /etc/pam.d/vsftpd <<EOF
#%PAM-1.0
session    optional pam_keyinit.so  force     revoke
auth       required pam_listfile.so item=user sense=deny file=/etc/vsftpd/ftpusers onerr=succeed
# auth       required pam_shells.so
auth       include  password-auth
account    include  password-auth
session    required pam_loginuid.so
session    include  password-auth
auth       required pam_userdb.so db=/etc/vsftpd/virt_users
account    required pam_userdb.so db=/etc/vsftpd/virt_users
session    required pam_loginuid.so
EOF

# Рисуем следующий конфиг для vsftpd vsftpd.conf Создаем файл с виртуальными пользователями:
# mcedit /etc/vsftpd/vsftpd.conf

cat > /etc/vsftpd/vsftpd.conf <<EOF
################################
##          CONFIG
##    ==| VIRTUAL user |==
##
################################

# Запуск сервера в режиме службы
listen=YES

# Работа в фоновом режиме
background=YES

# Разрешить подключаться виртуальным пользователям
guest_enable=YES

# Системный пользователь от имени котрого подключаются виртуальные
guest_username=ftp

# Виртуальные пользователи имеют те же привелегии, что и локальные
virtual_use_local_privs=YES

# Авто.назначение HOME каталога для Virt User
user_sub_token=$USER
local_root=/ftp/$USER

# Имя pam сервиса для vsftpd
pam_service_name=vsftpd

# Входящие соединения контроллируются через tcp_wrappers:
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

# Включение спец.ftp команд, некоторые клиенты без этого могут зависать
async_abor_enable=YES

# Локальные пользователи по-умолчанию не могут выходить за пределы своего домашнего каталога
chroot_local_user=YES

# Разрешить список пользователей, которые могут выходить за пределы домашнего каталога
chroot_list_enable=YES

# Список пользователей, которым разрешен выход из домашнего каталога
chroot_list_file=/etc/vsftpd/chroot_list

# Разрешить запись в корень chroot каталога пользователя
allow_writeable_chroot=YES

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

touch /etc/vsftpd/virt_users
#Добавляем туда в первую строку имя пользователя, во вторую его пароль. В конце не забудьте перейти на новую строку, это важно. Файл должен быть примерно таким:
cat > /etc/pam.d/vsftpd <<EOF
ftp-virt1
password1
ftp-virt2
password2
EOF

# Сохраняем файл и генерируем локальное хранилище учеток:
db_load -T -t hash -f /etc/vsftpd/virt_users /etc/vsftpd/virt_users.db

# Нужно создать каталоги для этих пользователей:
mkdir /ftp/ftp-virt1 /ftp/ftp-virt2

#Для папки /ftp надо назначить соответствующего владельца, от которого ftp сервер будет пускать виртуальных пользователей:
chown -R ftp. /ftp

#На этом настройка виртуальных пользователей ftp закончена. Перезапускаем vsftpd и пробуем залогиниться:
systemctl restart vsftpd

#Я набросал небольшой скрипт, чтобы было удобно добавлять новых пользователей, предлагаю воспользоваться:
CAT > $ADD_VIRTUSER <<EOF
#!/bin/sh

echo -n "Enter name of virtual user: "
read VIRTUSER

echo -n "Enter password: "
read VIRT

mkdir /ftp/$eirtuser
chown ftp. /ftp/$virtuser
touch /etc/vsftpd/users/$virtuser

echo "$virtuser" >> /etc/vsftpd/virt_users
echo "$virtpass" >> /etc/vsftpd/virt_users

db_load -T -t hash -f /etc/vsftpd/virt_users /etc/vsftpd/virt_users.db
EOF

# Делаете файл исполняемым и запускаете:
chmod 0700 $ADD_VIRTUSER
$ADD_VIRTUSER

#==== пользователь добавлен, можно сразу авиориз