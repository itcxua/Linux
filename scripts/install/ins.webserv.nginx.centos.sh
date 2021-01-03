X
Используешь Telegram? Подпишись на канал автора → посмотреть



 
Home » Linux » CentOS » Настройка web сервера nginx, php-fpm, php7 на CentOS 7
Настройка web сервера nginx, php-fpm, php7 на CentOS 7
Zerox Обновлено: 11.10.2019 CentOS, Linux 127 комментариев 98,610 Просмотры

Я уже писал статью по данной теме, и она формально даже не устарела, если брать все пакеты из официальных репозиториев. Сегодня я настрою производительный веб сервер на свежих версиях nginx, php-fpm, где сам php версии 7.1.  Сейчас использовать версию php54, которую предлагает CentOS по-умолчанию, очень странно, поэтому я решил актуализировать статью и все настроить в соответствии с современными реалиями.

Если у вас есть желание научиться строить и поддерживать высокодоступные и надежные системы, рекомендую познакомиться с онлайн-курсом "Administrator Linux. Professional" в OTUS. Курс не для новичков, для поступления нужно пройти вступительный тест.

Содержание:

1 Введение
2 Установка nginx на CentOS 7
3 Настройка nginx
4 Установка php-fpm 7.1
5 Настройка бесплатного ssl сертификата Lets Encrypt
6 Установка mariadb 10 на CentOS 7
7 Установка phpmyadmin
8 Доступ к сайту по sftp
9 Работа с сайтами разных пользователей на одном веб сервере
10 Ротация логов виртуальных хостов
11 Заключение
Данная статья является частью единого цикла статьей про сервер Centos. Если вы хотите использовать более новую версию системы, то читайте как настроить такой же web сервер на CentOS 8.

Введение

 
Ранее я рассказывал о настройке nginx и php-fpm. В принципе, статья полностью актуальна, по ней получится настроить веб сервер, если вас устраивают версии предложенных в стандартном репозитории пакетов. Если же хочется версий посвежее, то читайте далее.

Работать будем на сервере под управлением CentOS 7. Если у вас его еще нет, то читайте мои статьи на тему установки и базовой настройки centos. Не забудьте уделить внимание теме настройки iptables. В данной статье я ее не буду касаться, хотя тема важная для web сервера.

В своей тестовой среде я буду использовать следующие сущности.

hl.zeroxzed.ru	имя тестового виртуального хоста и сайта
/web/sites	директория для размещения виртуальных хостов
 95.169.190.64	 внешний ip адрес сервера
 p1m2a.zeroxzed.ru	 имя виртуального хоста для phpmyadmin
Подопытным сервером будет выступать виртуальная машина от ihor, характеристики следующие:

Процессор	2 ядра
Память	8 Gb
Диск	150 Gb SSD
Это кастомная настройка параметров. Они не оптимальны по цене, но мне были нужны именно такие.

Установка nginx на CentOS 7
Для установки самой свежей стабильной версии nginx на centos подключим родной репозиторий.

# rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
Если по какой-то причине ссылка изменится или устареет, то можно создать файл с конфигурацией репозитория nginx вручную. Для этого рисуем такой конфиг /etc/yum.repos.d/nginx.repo.

[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/$basearch/
gpgcheck=0
enabled=1
Устанавливаем nginx на сервер.

# yum install nginx


Запускаем nginx и добавляем в автозагрузку.

# systemctl start nginx
# systemctl enable nginx
Проверяем, запустился ли web сервер. Для этого идем по ссылке http://95.169.190.64/. Вы должны увидеть стандартную страницу заглушку.



Если страница не открывается, то скорее всего вы не настроили firewall. Свою статью по его настройке я приводил в самом начале.

Настройка nginx
Расскажу, как настроить nginx для работы разных виртуальных хостов. Создадим виртуальный хост и подготовим директории для размещения исходников сайта и панели управления phpmyadmin.

# mkdir -p /web/sites/hl.zeroxzed.ru/www && mkdir /web/sites/hl.zeroxzed.ru/log
# mkdir -p /web/sites/p1m2a.zeroxzed.ru/www && mkdir /web/sites/p1m2a.zeroxzed.ru/log
Создадим конфиги nginx для этих виртуальных хостов. Я сразу буду делать их с учетом https, который мы настроим позже. Так что после создания не надо перезапускать веб сервер и проверять работу - будут ошибки. Виртуальный хост сайта показан на примере wordpress. Конфигурация собрана на основе рекомендаций из официальной документации конкретно для веб сервера nginx.

# mcedit /etc/nginx/conf.d/hl.zeroxzed.ru.conf
server {
    listen 80;
    server_name hl.zeroxzed.ru;
    root /web/sites/hl.zeroxzed.ru/www/;
    index index.php index.html index.htm;
    access_log /web/sites/hl.zeroxzed.ru/log/access.log main;
    error_log /web/sites/hl.zeroxzed.ru/log/error.log;

    location / {
    return 301 https://hl.zeroxzed.ru$request_uri;
    }

    location ~* ^.+.(js|css|png|jpg|jpeg|gif|ico|woff)$ {
    return 301 https://hl.zeroxzed.ru$request_uri;
    }

    location ~ \.php$ {
    return 301 https://hl.zeroxzed.ru$request_uri;
    }

    location = /favicon.ico {
    log_not_found off;
    access_log off;
    }

    location = /robots.txt {
    rewrite ^ /robots.txt break;
    allow all;
    log_not_found off;
    access_log off;
    }

    location ~ /\.ht {
    deny all;
    }
}

server {
     listen  80;
     server_name  www.hl.zeroxzed.ru;
     rewrite ^ https://hl.zeroxzed.ru$request_uri? permanent;
}

server {
    listen 443 ssl http2;
    server_name hl.zeroxzed.ru;
    root /web/sites/hl.zeroxzed.ru/www/;
    index index.php index.html index.htm;
    access_log /web/sites/hl.zeroxzed.ru/log/ssl-access.log main;
    error_log /web/sites/hl.zeroxzed.ru/log/ssl-error.log;

    keepalive_timeout		60;
    ssl_certificate		/etc/letsencrypt/live/hl.zeroxzed.ru/fullchain.pem;
    ssl_certificate_key		/etc/letsencrypt/live/hl.zeroxzed.ru/privkey.pem;
    ssl_protocols 		TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_dhparam 		/etc/ssl/certs/dhparam.pem;
    add_header			Strict-Transport-Security 'max-age=604800';

    location / {
    try_files $uri $uri/ /index.php?$args;
    }

    location ~* ^.+.(js|css|png|jpg|jpeg|gif|ico|woff)$ {
    access_log off;
    expires max;
    }

    location ~ \.php$ {
    try_files  $uri =404;
    fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
    #fastcgi_pass    127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param DOCUMENT_ROOT /web/sites/hl.zeroxzed.ru/www/;
    fastcgi_param SCRIPT_FILENAME /web/sites/hl.zeroxzed.ru/www$fastcgi_script_name;
    fastcgi_param PATH_TRANSLATED /web/sites/hl.zeroxzed.ru/www$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_param QUERY_STRING $query_string;
    fastcgi_param REQUEST_METHOD $request_method;
    fastcgi_param CONTENT_TYPE $content_type;
    fastcgi_param CONTENT_LENGTH $content_length;
    fastcgi_param HTTPS on;
    fastcgi_intercept_errors on;
    fastcgi_ignore_client_abort off;
    fastcgi_connect_timeout 60;
    fastcgi_send_timeout 180;
    fastcgi_read_timeout 180;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 256k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    }

    location = /favicon.ico {
    log_not_found off;
    access_log off;
    }

    location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
    }

    location ~ /\.ht {
    deny all;
    }
}

server {
     listen  443 ssl http2;
     server_name  www.hl.zeroxzed.ru;
     rewrite ^ https://hl.zeroxzed.ru$request_uri? permanent;
}
В данной конфигурации настроены все необходимые редиректы, при этом отключен редирект файла robots.txt. Он отдельно отдается по http и https. Это требуется для яндекса во время перехода с http на https и склейки зеркал.

Для phpmyadmin рисуем конфиг попроще.

# mcedit /etc/nginx/conf.d/p1m2a.zeroxzed.ru.conf
server {
    listen 443 ssl http2;
    server_name p1m2a.zeroxzed.ru;
    root /web/sites/p1m2a.zeroxzed.ru/www/;
    index index.php index.html index.htm;
    access_log /web/sites/p1m2a.zeroxzed.ru/log/ssl-access.log main;
    error_log /web/sites/p1m2a.zeroxzed.ru/log/ssl-error.log;

    keepalive_timeout		60;
    ssl_certificate		/etc/letsencrypt/live/p1m2a.zeroxzed.ru/fullchain.pem;
    ssl_certificate_key		/etc/letsencrypt/live/p1m2a.zeroxzed.ru/privkey.pem;
    ssl_protocols 		TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_dhparam 		/etc/ssl/certs/dhparam.pem;
    add_header			Strict-Transport-Security 'max-age=604800';

    location ~ \.php$ {
    fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
    #fastcgi_pass    127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param DOCUMENT_ROOT /web/sites/p1m2a.zeroxzed.ru/www/;
    fastcgi_param SCRIPT_FILENAME /web/sites/p1m2a.zeroxzed.ru/www$fastcgi_script_name;
    fastcgi_param PATH_TRANSLATED /web/sites/p1m2a.zeroxzed.ru/www$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_param QUERY_STRING $query_string;
    fastcgi_param REQUEST_METHOD $request_method;
    fastcgi_param CONTENT_TYPE $content_type;
    fastcgi_param CONTENT_LENGTH $content_length;
    fastcgi_intercept_errors on;
    fastcgi_ignore_client_abort off;
    fastcgi_connect_timeout 60;
    fastcgi_send_timeout 180;
    fastcgi_read_timeout 180;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 256k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    }
}

server {
     listen  443 ssl http2;
     server_name  www.p1m2a.zeroxzed.ru;
     rewrite ^ https://p1m2a.zeroxzed.ru$request_uri? permanent;
}

server {
    listen 80;
    server_name p1m2a.zeroxzed.ru;
    root /web/sites/p1m2a.zeroxzed.ru/www/;
    index index.php index.html index.htm;
    access_log /web/sites/p1m2a.zeroxzed.ru/log/access.log main;
    error_log /web/sites/p1m2a.zeroxzed.ru/log/error.log;

    location / {
    return 301 https://p1m2a.zeroxzed.ru$request_uri;
    try_files $uri $uri/ /index.php?$args;
    }
}
Сохраняем конфиги виртуальных хостов nginx и продолжаем настройку производительного веб сервера. Более подробно о настройке Nginx читайте в отдельной статье, которая полностью посвящена только ему.

Установка php-fpm 7.1
Установка и настройка 7-й версии php на centos не очень простая задача. Ранее я уже рассказывал как обновить php до 7-й версии, но в итоге откатился назад. Прошло прилично времени и откатываться уже не будем, так как большинство проблем исправлены.

Основные трудности возникают с тем, что в официальных репозиториях очень старые версии php, но при этом они часто есть в зависимостях к другим пакетам. В итоге, обновившись неаккуратно до 7.1 можно получить проблемы с установкой и обновлением, к примеру, phpmyadmin или zabbix. В комментариях к моим статьям я иногда вижу эти ошибки и по тексту ошибок сразу понимаю, что проблема с зависимостями.

Вторая проблема в том, что надо определить, какой репозиторий использовать для установки php7. Их существует очень много. К примеру, мой хороший знакомый в своей статье по настройке web сервера использует репозиторий Webtatic. В принципе, чтобы просто поставить php 7-й версии это нормальный вариант. Но если вы после этого захотите установить phpmyadmin через yum уже ничего не получится. Будет ошибка зависимостей, которые нужно будет как-то руками разбирать.

То же самое будет и с другими пакетами. К примеру, zabbix без плясок с бубнами скорее всего не встанет. В сторонних репозиториях есть еще одна проблема. Иногда они закрываются. И это станет для вас большой проблемой на боевом сервере. Так что к выбору репозитория нужно подходить очень аккуратно и внимательно. Я до сих пор иногда встречаю настроенные сервера centos 5 с очень популярным в прошлом репозиторием centos.alt.ru, который закрылся. Сейчас это уже не так актуально, так как таких серверов осталось мало, но некоторое время назад мне это доставляло серьезные неудобства.

Для установки свежей версии php я буду использовать репозиторий Remi. Это известный и популярный репозиторий, который ведет сотрудник RedHat. И хотя надежность репозитория, который ведет один человек не так высока, но ничего лучше и надежнее remi лично я не нашел для своих целей. Если вы можете что-то посоветовать на этот счет - комментарии в вашем распоряжении. Буду благодарен за дельный совет.

Подключаем remi репозиторий для centos 7.

# rpm -Uhv http://rpms.remirepo.net/enterprise/remi-release-7.rpm
Я получил ошибку:

Retrieving http://rpms.remirepo.net/enterprise/remi-release-7.rpm
warning: /var/tmp/rpm-tmp.nwcDV1: Header V4 DSA/SHA1 Signature, key ID 00f97f56: NOKEY
error: Failed dependencies: 
       epel-release = 7 is needed by remi-release-7.3-2.el7.remi.noarch
Тут все понятно, нужен репозиторий epel. Те, кто готовили сервер по моей статье по базовой настройке сервера его уже подключили, а те кто не делали этого, подключают сейчас:

# yum install epel-release
После этого повторяем установку remi, все должно пройти нормально. Проверим список подключенных репозиториев.

# yum repolist


У меня такая картинка получилась.

Активируем репу remi-php71, для этого выполняем команду:

# yum-config-manager --enable remi-php71
Если получаете ошибку:

bash: yum-config-manager: command not found
то установите пакет yum-utils.

# yum install yum-utils
Теперь устанавливаем php7.1.

# yum install php71


Установим php-fpm и наиболее популярные модули, которые могут пригодится в процессе эксплуатации веб сервера.

# yum install php-fpm php-cli php-mysql php-gd php-ldap php-odbc php-pdo php-pecl-memcache php-opcache php-pear php-xml php-xmlrpc php-mbstring php-snmp php-soap php-zip


Запускаем php-fpm и добавляем в автозагрузку.

# systemctl start php-fpm
# systemctl enable php-fpm
Проверяем, запустился ли он.

# netstat -tulpn | grep php-fpm
tcp 0 0 127.0.0.1:9000 0.0.0.0:* LISTEN 9084/php-fpm: maste
Все в порядке, повис на порту 9000. Запустим его через unix сокет. Для этого открываем конфиг /etc/php-fpm.d/www.conf и комментируем строку:

;listen = 127.0.0.1:9000
Вместо нее добавляем несколько других:

listen = /var/run/php-fpm/php-fpm.sock
listen.mode = 0660
listen.owner = nginx
listen.group = nginx
Заодно измените пользователя, от которого будет работать php-fpm. Вместо apache укажите nginx.

user = nginx
group = nginx
Перезапускаем php-fpm.

# systemctl restart php-fpm
Проверяем, стартовал ли указанный сокет.

# ll /var/run/php-fpm/php-fpm.sock 
srw-rw----. 1 nginx nginx 0 Oct 26 18:08 /var/run/php-fpm/php-fpm.sock
На текущий момент с настройкой php-fpm закончили, двигаемся дальше.

Для того, чтобы проверить работу нашего веб сервера, нужно установить ssl сертификаты. Без них nginx с текущим конфигом не запустится. Исправляем это.

Настройка бесплатного ssl сертификата Lets Encrypt
 
Устанавливаем пакет certbot для получения бесплатного ssl сертификата от let's encrypt.

# yum install certbot
Запускаем программу для генерации сертификата.

# certbot certonly
Вам в консоли будут заданы несколько вопросов. Вот мои ответы, необходимые для успешного получения сертификата. Первый раз мы получим сертификаты, используя временный веб сервер самого certbot, так как наш еще не работает. Далее обновлять сертификаты будем в автоматическом режиме с помощью временной директории в корне виртуального хоста.

# certbot certonly
Saving debug log to /var/log/letsencrypt/letsencrypt.log

How would you like to authenticate with the ACME CA?
-------------------------------------------------------------------------------
1: Spin up a temporary webserver (standalone)
2: Place files in webroot directory (webroot)
-------------------------------------------------------------------------------
Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 1
Plugins selected: Authenticator standalone, Installer None
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel): zeroxzed@gmail.com
Starting new HTTPS connection (1): acme-v01.api.letsencrypt.org

-------------------------------------------------------------------------------
Please read the Terms of Service at
https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf. You must agree
in order to register with the ACME server at
https://acme-v01.api.letsencrypt.org/directory
-------------------------------------------------------------------------------
(A)gree/(C)ancel: A

-------------------------------------------------------------------------------
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about EFF and
our work to encrypt the web, protect its users and defend digital rights.
-------------------------------------------------------------------------------
(Y)es/(N)o: N
Please enter in your domain name(s) (comma and/or space separated)  (Enter 'c'
to cancel): hl.zeroxzed.ru
Obtaining a new certificate
Performing the following challenges:
tls-sni-01 challenge for hl.zeroxzed.ru
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/hl.zeroxzed.ru/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/hl.zeroxzed.ru/privkey.pem
   Your cert will expire on 2018-01-24. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
Для успешного создания бесплатных ssl сертификатов от lets encrypt у вас должны быть корректно настроены DNS записи для доменов, на которые выпускаются сертификаты.

Итак, сертификаты получили. Теперь можно проверить конфигурацию nginx и запустить его. Проверяем конфиг:

# nginx -t
Если получаете ошибку:

nginx: [emerg] BIO_new_file("/etc/ssl/certs/dhparam.pem") failed (SSL: error:02001002:system library:fopen:No such file or directory:fopen('/etc/ssl/certs/dhparam.pem','r') error:2006D080:BIO routines:BIO_new_file:no such file)
nginx: configuration file /etc/nginx/nginx.conf test failed
То генерируете необходимый ключ:

# openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
Генерация будет длиться долго (у меня 20 минут длилось на двух ядрах). Снова проверяйте конфигурацию. Если ошибок нет, то перезапустим nginx.

# systemctl restart nginx
Настройка nginx на этом завершена. Он должен корректно запуститься и работать в рабочем режиме.

Теперь сделаем так, чтобы сертификаты автоматически обновлялись перед истечением срока действия. Для этого необходимо изменить конфигурации доменов. Они располагаются в директории /etc/letsencrypt/renewal. Так как мы генерировали сертификаты с помощью временного веб сервера, наш текущий конфиг hl.zeroxzed.ru.conf выглядит вот так:

# renew_before_expiry = 30 days
version = 0.18.1
archive_dir = /etc/letsencrypt/archive/hl.zeroxzed.ru
cert = /etc/letsencrypt/live/hl.zeroxzed.ru/cert.pem
privkey = /etc/letsencrypt/live/hl.zeroxzed.ru/privkey.pem
chain = /etc/letsencrypt/live/hl.zeroxzed.ru/chain.pem
fullchain = /etc/letsencrypt/live/hl.zeroxzed.ru/fullchain.pem

# Options used in the renewal process
[renewalparams]
authenticator = standalone
installer = None
account = e9c86e6aa57b45f9614bc7c0015927a5
Приводим его к следующему виду:

# renew_before_expiry = 30 days
version = 0.18.1
archive_dir = /etc/letsencrypt/archive/hl.zeroxzed.ru
cert = /etc/letsencrypt/live/hl.zeroxzed.ru/cert.pem
privkey = /etc/letsencrypt/live/hl.zeroxzed.ru/privkey.pem
chain = /etc/letsencrypt/live/hl.zeroxzed.ru/chain.pem
fullchain = /etc/letsencrypt/live/hl.zeroxzed.ru/fullchain.pem

# Options used in the renewal process
[renewalparams]
authenticator = webroot
installer = None
account = e9c86e6aa57b45f9614bc7c0015927a5
post_hook = nginx -s reload
[[webroot_map]]
www.hl.zeroxzed.ru = /web/sites/hl.zeroxzed.ru/www
hl.zeroxzed.ru = /web/sites/hl.zeroxzed.ru/www
По аналогии делаете с остальными виртуальными хостами, для которых используете бесплатные сертификаты let's encrypt. Осталось дело за малым - настроить автоматический выпуск новых ssl сертификатов, взамен просроченным. Для этого добавляем в /etc/crontab следующую строку:

# Cert Renewal
30 2 * * * root /usr/bin/certbot renew --post-hook "nginx -s reload" >> /var/log/le-renew.log
Все, с сертификатами закончили. Двигаемся дальше в настройке web сервера.

Установка mariadb 10 на CentOS 7
Дошла очередь до установки сервера баз данных для web сервера на CentOS 7 - MariaDB. По аналогии с другим софтом, в официальном репозитории очень старая версия mariadb - 5.5. Я же буду устанавливать последнюю стабильную версию на момент написания статьи - 10.2.

Для того, чтобы подключить репозиторий MariaDB, можно воспользоваться специальной страницей на официальном сайте, где можно задать параметры системы и получить конфиг репозитория.

В моем случае конфиг получился следующий.

# cat /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
Устанавливаем последнюю версию mariadb на centos.

# yum install MariaDB-server MariaDB-client


Убедитесь, что база данных ставится из нужного репозитория.

Запускаем mariadb и добавляем в автозагрузку.

# systemctl start mariadb
# systemctl enable mariadb
Запускаем скрипт начальной конфигурации mysql и задаем пароль для root. Все остальное можно оставить по-умолчанию.

# /usr/bin/mysql_secure_installation
Сервер баз данных mysql для нашего web сервера готов. Продолжаем настройку. Установим панель управления mysql - phpmyadmin.

Установка phpmyadmin
 
Кратко расскажу про установку phpmyadmin в контексте данной статьи. Подробно не буду останавливаться на этом, так как статья и так получается очень объемная, а я еще не все рассказал. Вопрос настройки phpmyadmin я очень подробно рассмотрел отдельно. За подробностями можно сходить туда.

Устанавливаем phpmyadmin через yum. Если ранее все сделали правильно, то конфликтов с зависимостями быть не должно.

# yum install phpmyadmin


Phpmyadmin по-умолчанию сконфигурирована для работы с httpd. Для того, чтобы в будущем автоматически обновлять ее, просто сделаем символьную ссылку из директории с исходниками панели в наш виртуальный хост.

# rm -df /web/sites/p1m2a.zeroxzed.ru/www
# ln -s /usr/share/phpMyAdmin /web/sites/p1m2a.zeroxzed.ru/www
Выставляем правильные права на директорию с php сессиями. Без этого работать phpmyadmin не будет.

# chown nginx:nginx /var/lib/php/session/
Можно заходить и проверять работу phpmyadmin. Ее установка закончена.

Доступ к сайту по sftp
Настройка сервера почти завершена. Если вы администратор и единственный пользователь, то больше можно ничего не делать. Вы и так сможете загрузить на сервер все что нужно тем или иным способом. Если же вы будете передавать управление сайтами другим людям, им нужен доступ к директории с исходниками сайта. Раньше для этих целей повсеместно использовали ftp. Если вы хотите так сделать, у меня есть статья по настройке ftp сервера vsftpd.

Я же предлагаю использовать sftp по нескольким причинам:

Он безопаснее.
Его быстрее настроить.
Не надо отдельно настраивать firewall.
Статью по настройке sftp доступа я уже тоже писал, все подробности там. Здесь без комментариев выполним необходимые действия.

Создаем пользователя для подключения к сайту. Я обычно использую имя пользователя пересекающееся с названием сайта. Так удобнее управлять.

# useradd -s /sbin/nologin hl.zeroxzed.ru
# passwd hl.zeroxzed.ru
Открываем конфиг ssh по пути /etc/ssh/sshd_config и комментируем там одну строку, добавляя далее несколько новых.

#Subsystem sftp /usr/libexec/openssh/sftp-server
Subsystem sftp internal-sftp
Match User hl.zeroxzed.ru
ChrootDirectory /web/sites/hl.zeroxzed.ru
ForceCommand internal-sftp
Перезапускаем службу sshd.

# systemctl restart sshd
Этого уже достаточно, чтобы вы могли подключиться к сайту, к примеру, с помощью программы winscp. Если что-то пойдет не так и будут какие-то ошибки, то смотреть подробности нужно в логе /var/log/secure. Но тут возникает много нюансов с правами к файлам и директориям. Дальше я расскажу, как их аккуратно и грамотно разрулить, чтобы у нас не было проблем с дальнейшей работой сайтов от разных пользователей.

Работа с сайтами разных пользователей на одном веб сервере
 
Самый простой способ решить проблему с правами доступа, это сделать владельцем папки с сайтом пользователя, который подключается по sftp. Тогда он сможет нормально работать с файлами, загружать и удалять их. Если доступ в качестве группы установить для nginx, то в целом все будет работать. Для каких-то сайтов такой вариант может оказаться подходящим. То есть сделать надо вот так:

# chown -R hl.zeroxzed.ru:nginx /web/sites/hl.zeroxzed.ru/
# chmod -R 0775 /web/sites/hl.zeroxzed.ru/
Но при такой схеме будут проблемы с движками сайтов, которые автоматом что-то к себе загружают. Какие-то галереи не будут работать. К примеру, wordpress не сможет автоматически загружать плагины, будет просить доступ к ftp. В общем, могут возникнуть некоторые неудобства. Сейчас мы их исправим.

Еще обращаю внимание на один нюанс. Chroot доступ для sftp не будет работать, если владельцем директории, куда чрутимся, будет не root. Только что мы сделали владельцем каталога с сайтом и всего, что внутри него пользователя hl.zeroxzed.ru. Теперь надо вернуть обратно владельцем исходного каталога рута, а все, что внутри него остается как мы и хотим - будет принадлежать hl.zeroxzed.ru.

# chown root:root /web/sites/hl.zeroxzed.ru/
# chmod 0755 /web/sites/hl.zeroxzed.ru/
А теперь сделаем все красиво. Назначаем владельцем содержимого нашего сайта только отдельного пользователя.

# chown -R hl.zeroxzed.ru:hl.zeroxzed.ru /web/sites/hl.zeroxzed.ru/
Возвращаем обратно рута владельцем корня chroot.

# chown root:root /web/sites/hl.zeroxzed.ru/
# chmod 0755 /web/sites/hl.zeroxzed.ru/
Обращаю внимание, что сначала мы рекурсивно назначаем права на все содержимое директорий, а потом возвращаем владельца root только на корень.

Добавляем пользователя nginx в группу hl.zeroxzed.ru.

# usermod -aG hl.zeroxzed.ru nginx
Создаем отдельный pool для php-fpm, который будет обслуживать сайт hl.zeroxzed.ru и будет запускаться от этого пользователя. Для этого копируем существующий конфиг /etc/php-fpm.d/www.conf и изменяем в нем несколько строк.

# cd /etc/php-fpm.d && cp www.conf hl.zeroxzed.ru.conf
[hl.zeroxzed.ru]
user = hl.zeroxzed.ru
group = hl.zeroxzed.ru
listen = /var/run/php-fpm/hl.zeroxzed.ru.sock
listen.owner = hl.zeroxzed.ru
listen.group = hl.zeroxzed.ru
Мы поменяли название пула, запустили его от отдельного пользователя и назначили ему отдельный сокет. Теперь идем в настройки этого виртуального хоста в nginx - /etc/nginx/conf.d/hl.zeroxzed.ru.conf и везде меняем старое значение сокета

fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
на новое

fastcgi_pass unix:/var/run/php-fpm/hl.zeroxzed.ru.sock;
Перезапускаем nginx и php-fpm и проверяем работу сайта от отдельного пользователя.

# systemctl restart nginx
# systemctl restart php-fpm
Я рекомендую подключиться по sftp, закинуть исходники wordpress, установить его и добавить новую тему, чтобы проверить, что все корректно работает.  По аналогии проделанные выше действия повторяются для всех остальных сайтов.

Ротация логов виртуальных хостов
Последний штрих в настройке web сервера - ротация логов виртуальных хостов. Если этого не сделать, то через какое-то, обычно продолжительное, время возникает проблема в связи с огромным размером лог файла.

У нас уже будет файл конфигурации logrotate для nginx, который был создан во время установки - /etc/logrotate.d/nginx. Приведем его к следующему виду:

/var/log/nginx/*log
/web/sites/p1m2a.zeroxzed.ru/log/*log {

    create 0644 nginx nginx
    size=1M
    rotate 10
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        /bin/kill -USR1 `cat /run/nginx.pid 2>/dev/null` 2>/dev/null || true
    endscript
}

/web/sites/hl.zeroxzed.ru/log/*log {

    create 0644 hl.zeroxzed.ru hl.zeroxzed.ru
    size=1M
    rotate 10
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        /bin/kill -USR1 `cat /run/nginx.pid 2>/dev/null` 2>/dev/null || true
    endscript
}
Я предлагаю ротировать файлы логов по достижению ими размера в 1Мб, сжимать после ротации и хранить 10 архивов с логом. Для виртуальных хостов, работающих от отдельного пользователя, новые логи создаются сразу с соответствующими правами, чтобы у пользователя был доступ к ним. Для всех остальных хостов можно использовать самое первое правило, просто добавляя туда новые пути для логов.

Это просто пример конфигурации. Все параметры вы можете поменять по своему усмотрению. Примеров конфигурации logrotate в интернете много.

На этом все. Я рассмотрел все основные моменты, которые необходимы для установки и настройки производительного web сервера на основе nginx и php-fpm последних версий. При этом рассказал о некоторых вещах, которые повышают удобство и гибкость эксплуатации сервера.

Заключение
 
Не понравилась статья и хочешь научить меня администрировать? Пожалуйста, я люблю учиться. Комментарии в твоем распоряжении. Расскажи, как сделать правильно!
Тема настройки веб сервера обширна. Рассмотреть все варианты в одной статье невозможно, так как функционал будет разниться, в зависимости от назначения сервера. Тем не менее приведу еще несколько ссылок на материалы, которые имеют отношение к настройке web сервера:

Полный бэкап сервера или отдельных сайтов.
Мониторинг веб сервера и веб сайта с помощью zabbix.
Защита админки wordpress с помощью fail2ban.
Если у вас будут проблемы с ботами, то пригодится статья по блокировке доступа к сайту по странам.
Если еще что-то полезное вспомню, добавлю ссылки. Пока вроде все. Жду комментариев и отзывов. Написал все по своему опыту, как я обычно настраиваю веб сервера. Возможно что-то можно сделать более удобно и правильно.

Эта статья будет первой из цикла статей по настройке современного веб сервера. Далее мы будем защищать web сервер и готовить его к максимальным нагрузкам.

Напоминаю, что данная статья является частью единого цикла статьей про сервер Centos.

Онлайн курс по Linux
Если у вас есть желание научиться строить и поддерживать высокодоступные и надежные системы, рекомендую познакомиться с онлайн-курсом "Administrator Linux. Professional" в OTUS. Курс не для новичков, для поступления нужны базовые знания по сетям и установке Linux на виртуалку. Обучение длится 5 месяцев, после чего успешные выпускники курса смогут пройти собеседования у партнеров. Что даст вам этот курс:
Знание архитектуры Linux.
Освоение современных методов и инструментов анализа и обработки данных.
Умение подбирать конфигурацию под необходимые задачи, управлять процессами и обеспечивать безопасность системы.
Владение основными рабочими инструментами системного администратора.
Понимание особенностей развертывания, настройки и обслуживания сетей, построенных на базе Linux.
Способность быстро решать возникающие проблемы и обеспечивать стабильную и бесперебойную работу системы.
Проверьте себя на вступительном тесте и смотрите подробнее программу по ссылке.
Помогла статья? Подписывайся на telegram канал автора
Анонсы всех статей, плюс много другой полезной и интересной информации, которая не попадает на сайт. Скачать pdf
Tags CENTOS NGINX WEBSERVER

Автор Zerox

Владимир, системный администратор, автор сайта. Люблю настраивать сервера, изучать что-то новое, делиться знаниями, писать интересные и полезные статьи. Открыт к диалогу и сотрудничеству. Если вам интересно узнать обо мне побольше, то можете послушать интервью. Запись на моем канале - https://t.me/srv_admin/425 или на сайте в контактах.
Предыдущая
Настройка мониторинга asterisk в zabbix
Следующая
Ошибка установки Zabbix на nginx и php-fpm7
127 комментариев

Alex17.11.2020 at 11:31
server {
listen 80;
server_name http://www.hl.zeroxzed.ru;
rewrite ^ https://hl.zeroxzed.ru$request_uri? permanent;
}
Не понятно зачем в nginx открывать отдельный сервер для www* когда можно в первом же дописать

server {
listen 80;
server_name hl.zeroxzed.ru http://www.hl.zeroxzed.ru;

Ответить

Zerox17.11.2020 at 11:34
Можно сделать и так. Когда отдельные вирт хосты на каждый поддомен получается более универсальная конфигурация.

Ответить

Иван18.09.2020 at 13:00
У меня возникла проблема через 90 дней с обновление сертификатов - они не обновились. Нашел проблему вот такой командой - crontab -u root /etc/crontab. Нужно было добавить перенос строки в конец файла.

Ответить

Zerox18.09.2020 at 16:49
Да, важно следить за этим. В crontab, как и в fstab, в конце обязательно должен быть переход на новую строку.

Ответить

Иван09.09.2020 at 11:57
Владимир, замечательная статья, все очень понятно написано, спасибо вам за вашу работу!
Могли бы вы подсказать как в данной конфигурации на отдельный домен поставить другую версию PHP?

Ответить

Zerox09.09.2020 at 12:17
Я так сходу не отвечу, так как сам не делал. Но в общем случае, вам просто надо установить еще одну версию php на сервере, запустить php-fpm от этой версии на отдельном сокете и этот сокет прописать виртуальному хосту. Если бы мне сейчас это нужно было сделать, я бы запустил нужную версию php в докер контейнере. Это проще, чем ставить несколько версий пакетов на один и тот же сервер.

Ответить

Дмитрий22.07.2020 at 09:53
Здравствуйте, Владимир, столкнулся с проблемой, после перезапуска сервера пропадает /var/run/php-fpm
Настройка правильная, создаю вручную, все работает.
Не сталкивались с проблемой?Здравствуйте, Владимир, столкнулся с проблемой, после перезапуска сервера пропадает /var/run/php-fpm
Настройка правильная, создаю вручную, все работает.
Не сталкивались с проблемой?

Ответить

Дмитрий22.07.2020 at 11:16
решил вопрос пока так, добавил в скрипт старта
ExecStartPre=/usr/bin/mkdir -p -m 755 /var/run/php-fpm

коряво, но работает, причину буду выяснять

Ответить

Zerox22.07.2020 at 11:31
/var/run/php-fpm это сокет, который создает служба php-fpm во время запуска. Не очень понял, что именно у вас происходит. Служба запускается, а сокет не создается? Или служба не стартует при запуске сервера?

Ответить

Дмитрий22.07.2020 at 11:37
Не стартует служа, пропадает директория и не создается

Ответить

Zerox22.07.2020 at 11:45
Надо лог тогда смотреть, почему не стартует. Системный лог и лог php-fpm.

Ответить

Максим20.03.2020 at 12:16
В чем может быть проблема, CentOS на vbox. После перезагрузки, пока не введу команду /etc/iptables.sh , подключение по ssh не работате.

Ответить

Максим20.03.2020 at 11:48
Здравствуйте. Всё вроде делаю по инструкции, но при вооде # netstat -tulpn | grep php-fpm, ничего нет. Т.е. php не запускается. Уже все статьи пролистал где было что-то про php-fpm. Вообще хочу установить Zabbix 4 на CentOS 7.

Ответить

Максим20.03.2020 at 12:23
Решено. Откатился до установки php и установил снова. Заработало всё.

Ответить

Сергей18.03.2020 at 22:04
И ещё вопрос, phpmyadmin на английском, хотя выбран русский язык. Подскажите, как сделать phpmyadmin на русском. На php 5-й версии всё норм было.

Ответить

Сергей18.03.2020 at 22:02
команда ln -s /usr/share/phpMyAdmin /web/sites/p1m2a.zeroxzed.ru/www не работает
она создает ссылку, но файлы, которые в phpmyadmin, не видятся и соответственно phpmyadmin не работает. Только копирование помогает.
Подскажите как сделать рабочую ссылку.

Ответить

Иван14.03.2020 at 19:36
Сделал все как по инструкции, установил себе wordpress, но теперь в логах вот такая постоянная ошибка забивает лог, не понимаю что я пропустил.

[error] 917#917: *30 FastCGI sent in stderr: "PHP message: PHP Warning: session_start(): open(/var/lib/php/session/sess_hl1psdegfemi4p, O_RDWR) failed: Permission denied (13) in web/sites/site.ru/www/wp-content/themes/fr/functions.php on line 19PHP message: PHP Warning: session_start(): Failed to read session data: files (path: /var/lib/php/session) in /web/sites/site.ru/www/wp-content/themes/fr/functions.php on line 19" while reading response header from upstream, client: , server: site.ru, request: "GET /%d0%bf%d1%80%d0%be%d0%b3%d1%80%d0%bf%d0%b5%d1%80%d0%b5%d0%b4%d0%b0%d1%87/ HTTP/2.0", upstream: "fastcgi://unix:/var/run/php-fpm/site.ru.sock:", host: "site.ru", referrer: "https://site.ru/%d0%b8%d1%8d1%8f/"

Ответить

Zerox14.03.2020 at 19:49
У вашего сайта не хватает прав на запись в директорию с сессиями php - /var/lib/php/session/ Либо назначьте права на эту директорию такие же, как у php-fpm пула вашего сайта. Но это если у вас сайт один. Если сайтов несколько, то лучше через настройки php вынести для каждого виртуального хоста директорию с сессиями отдельно и назначить нужные права доступа.

Ответить

Иван14.03.2020 at 19:52
А как это сделать? Какие нужно права выставить? Пока сайт один, но вдруг еще будут.

Ответить

Иван14.03.2020 at 19:55
Сейчас вот так стоит https://prnt.sc/rgbz4k

Ответить

Антон27.02.2020 at 17:07
Здравствуйте, в общем не работает ничего, ИМХО инструкция неполная, не хватает раздела с запуском(входом) на виртуальные хосты. Специально установил CentOS 7 с нуля, прошелся по инструкции, все службы работают ошибок нет, назначил права, настроил sftp по пользователю, но не открывается веб интерфейс cms или phpmyadmin. Как запускать то их, прописаны конфиги для nginx, настроены пользователи доступ к папкам. Даже созданы записи на DNS сервере локальном, но чего то нехватает, в статье нет упоминания про вход на веб интерфейсы вообще, при попытке ввода в браузере ip адреса веб сервера идет редирект на https://corp.local и все пустая страничка привожу конфиги 2х виртуальных хостов nginx может там что напутал подскажите:

server {
    listen 80;
    server_name corp.local;
    root /web/sites/corp.local/www/;
    index index.php index.html index.htm;
    access_log /web/sites/corp.local/log/access.log main;
    error_log /web/sites/corp.local/log/error.log;

    location / {
    return 301 http://corp.local$request_uri;
    }

    location ~* ^.+.(js|css|png|jpg|jpeg|gif|ico|woff)$ {
    return 301 http://corp.local$request_uri;
    }

    location ~ \.php$ {
    return 301 http://corp.local$request_uri;
    }

    location = /favicon.ico {
    log_not_found off;
    access_log off;
    }

    location = /robots.txt {
    rewrite ^ /robots.txt break;
    allow all;
    log_not_found off;
    access_log off;
    }

    location ~ /\.ht {
    deny all;
    }
}

#server {
     #listen  80;
     #server_name  www.corp.local;
     #rewrite ^ https://corp.local$request_uri? permanent;
#}

server {
    #listen 443 ssl http2;
    #server_name corp.local;
    #root /web/sites/corp.local/www/;
    #index index.php index.html index.htm;
    #access_log /web/sites/corp.local/log/ssl-access.log main;
    #error_log /web/sites/corp.local/log/ssl-error.log;

    #keepalive_timeout		60;
    #ssl_certificate		/etc/letsencrypt/live/corp.local/fullchain.pem;
    #ssl_certificate_key		/etc/letsencrypt/live/corp.local/privkey.pem;
    #ssl_protocols 		TLSv1 TLSv1.1 TLSv1.2;
    #ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    #ssl_dhparam 		/etc/ssl/certs/dhparam.pem;
    #add_header			Strict-Transport-Security 'max-age=604800';

    location / {
    try_files $uri $uri/ /index.php?$args;
    }

    location ~* ^.+.(js|css|png|jpg|jpeg|gif|ico|woff)$ {
    access_log off;
    expires max;
    }

    location ~ \.php$ {
    try_files  $uri =404;
    fastcgi_pass   unix:/var/run/php-fpm/corp.local.sock;
    #fastcgi_pass    127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param DOCUMENT_ROOT /web/sites/corp.local/www/;
    fastcgi_param SCRIPT_FILENAME /web/sites/corp.local/www$fastcgi_script_name;
    fastcgi_param PATH_TRANSLATED /web/sites/corp.local/www$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_param QUERY_STRING $query_string;
    fastcgi_param REQUEST_METHOD $request_method;
    fastcgi_param CONTENT_TYPE $content_type;
    fastcgi_param CONTENT_LENGTH $content_length;
    fastcgi_param HTTPS on;
    fastcgi_intercept_errors on;
    fastcgi_ignore_client_abort off;
    fastcgi_connect_timeout 60;
    fastcgi_send_timeout 180;
    fastcgi_read_timeout 180;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 256k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    }

    location = /favicon.ico {
    log_not_found off;
    access_log off;
    }

    location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
    }

    location ~ /\.ht {
    deny all;
    }
}

#server {
     #listen  443 ssl http2;
     #server_name  www.corp.local;
     #rewrite ^ https://corp.local$request_uri? permanent;
#}



И второй для PHPmyadmin

server {
    #listen 443 ssl http2;
    #server_name pma.local;
    #root /web/sites/pma.local/www/;
    #index index.php index.html index.htm;
    #access_log /web/sites/pma.local/log/ssl-access.log main;
    #error_log /web/sites/pma.local/log/ssl-error.log;

    #keepalive_timeout		60;
    #ssl_certificate		/etc/letsencrypt/live/pma.local/fullchain.pem;
    #ssl_certificate_key		/etc/letsencrypt/live/pma.local/privkey.pem;
    #ssl_protocols 		TLSv1 TLSv1.1 TLSv1.2;
    #ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    #ssl_dhparam 		/etc/ssl/certs/dhparam.pem;
    #add_header			Strict-Transport-Security 'max-age=604800';

    location ~ \.php$ {
    fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
    #fastcgi_pass    127.0.0.1:9000;
    fastcgi_index index.php;
    fastcgi_param DOCUMENT_ROOT /web/sites/pma.local/www/;
    fastcgi_param SCRIPT_FILENAME /web/sites/pma.local/www$fastcgi_script_name;
    fastcgi_param PATH_TRANSLATED /web/sites/pma.local/www$fastcgi_script_name;
    include fastcgi_params;
    fastcgi_param QUERY_STRING $query_string;
    fastcgi_param REQUEST_METHOD $request_method;
    fastcgi_param CONTENT_TYPE $content_type;
    fastcgi_param CONTENT_LENGTH $content_length;
    fastcgi_intercept_errors on;
    fastcgi_ignore_client_abort off;
    fastcgi_connect_timeout 60;
    fastcgi_send_timeout 180;
    fastcgi_read_timeout 180;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 256k;
    fastcgi_busy_buffers_size 256k;
    fastcgi_temp_file_write_size 256k;
    }
}

#server {
     #listen  443 ssl http2;
     #server_name  www.pma.local;
     #rewrite ^ https://pma.local$request_uri? permanent;
#}

server {
    listen 80;
    server_name pma.local;
    root /web/sites/pma.local/www/;
    index index.php index.html index.htm;
    access_log /web/sites/pma.local/log/access.log main;
    error_log /web/sites/pma.local/log/error.log;

    location / {
    return 301 http://pma.local$request_uri;
    try_files $uri $uri/ /index.php?$args;
    }
}
Ответить

Zerox27.02.2020 at 21:01
Я не понимаю, что значит вход на веб интерфейс? Статья 100% рабочая. Я сам ей пользуюсь постоянно.

Ответить

Антон28.02.2020 at 15:22
Здравствуйте, разобрался с запуском, подкорректировал конфиги виртуальных хостов и прописал себе на комп в hosts правила сопоставления хостов к адресу, PMA заработал как надо, но вот CMS не хочет запускаться отдает ошибку бекенда в логах виртуального хоста:

020/02/28 14:48:24 [error] 2318#2318: *1 FastCGI sent in stderr: "PHP message: PHP Warning: Unknown: open(/var/lib/php/session/sess_njh18vfnccjhj1lmbgadv043r3, O_RDWR) failed: Permission denied (13) in Unknown on line 0
PHP message: PHP Warning: Unknown: Failed to write session data (files). Please verify that the current setting of session.save_path is correct (/var/lib/php/session) in Unknown on line 0" while reading upstream, client: 10.3.0.135, server: corp.local, request: "GET /setup/index.php?s=set HTTP/1.1", upstream: "fastcgi://unix:/var/run/php-fpm/corp.local.sock:", host: "corp.local", referrer: "http://corp.local/setup/"

Судя по ошибке php-fpm для конкретного сокета не может записать информацию в пользовательские сессии не хватает прав, я настраивал по вашей инструкции в конце данной статьи трюк с правами для sftp, но права на директорию сессий там не настраивались.
Смотрю от какого пользователя выполняется php код командой:

# ps aux |grep php-fpm

Результат:
root 2583 0.2 1.6 545272 30496 ? Ss 15:07 0:00 php-fpm: master process (/etc/php-fpm.conf)
nginx 2584 0.0 0.4 545068 7720 ? S 15:07 0:00 php-fpm: pool www
nginx 2585 0.0 0.4 545068 7720 ? S 15:07 0:00 php-fpm: pool www
corp.lo+ 2586 0.0 0.5 545200 10284 ? S 15:07 0:00 php-fpm: pool corp.local
corp.lo+ 2587 0.0 0.4 545200 9112 ? S 15:07 0:00 php-fpm: pool corp.local
corp.lo+ 2588 0.0 0.4 545068 7716 ? S 15:07 0:00 php-fpm: pool corp.local
corp.lo+ 2589 0.0 0.4 545068 7720 ? S 15:07 0:00 php-fpm: pool corp.local
corp.lo+ 2590 0.0 0.4 545068 7720 ? S 15:07 0:00 php-fpm: pool corp.local
root 2593 0.0 0.0 112732 964 pts/0 S+ 15:08 0:00 grep --color=auto php-fpm

Проверяю права на хранилище пользовательских сессий командой:

# ls -alh /var/lib/php/session

Результат:
drwxrwxrwt 2 nginx nginx 135 фев 28 14:52 .
drwxr-xr-x 3 root root 21 фев 27 16:27 ..
-rw------- 1 nginx nginx 36K фев 28 15:18 sess_76ju5eh54247mpuurve4th18o0rbqtrn
-rw------- 1 corp.local corp.local 0 фев 28 14:52 sess_njh18vfnccjhj1lmbgadv043r3
-rw------- 1 nginx nginx 1,7K фев 28 13:20 sess_qdaj7d1cq0apjp97a1i3nfetg0piglb2

Вопрос: как мне поправить права для указанной директории, что прописать желательно командой с параметрами или может быть посоветуете какое-то альтернативное решение проблемы, заранее благодарен.

Ответить

Антон28.02.2020 at 16:10
Удалось решить проблему своими силами при помощи гугления, опишу порядок действий, думаю автору стоить взять на заметку или внести в статью. Для корректной работы разных виртуальных хостов в хранилище сессий лучше создать отдельную директорию для хранения сессий по каждому из виртуальных хостов.
Проверяем права:
# ls -l /var/lib/php/
total 228
drwxrwx--- 2 root apache 229376 Sep 30 08:59 session

Создаём каталог для каждого пользователя каждого php-fpm пула:
# mkdir /var/lib/php/session/corp.local

Устанавливаем владельца, который указан в user/group пула, и даём права на доступ к каталогу только ему:

# chown corp.local:corp.local /var/lib/php/session/corp.local && chmod 700 /var/lib/php/session/corp.local

Редактируем настройки пула, в данном случае это файл /etc/php-fpm.d/corp.local.conf, изменяем параметр:
php_admin_value[session.save_path] = /var/lib/php/session/corp.local

Перезапускаем PHP-FPM:
# service php-fpm restart
Stopping php-fpm: [ OK ]
Starting php-fpm: [ OK ]

Устанавливаем полный доступ на директорию session:
# chmod 777 /var/lib/php/session/

Проверяем каталог:
# ls -l /var/lib/php/session/corp.local
total 0
-rw------- 1 rtfm rtfm 0 Oct 4 10:10 sess_5j5k1r3t3dailk3s7lq8871gu7
-rw------- 1 rtfm rtfm 0 Oct 4 10:10 sess_80fslkcad1mmhbm7eeil6pf937
-rw------- 1 rtfm rtfm 0 Oct 4 10:10 sess_pfkp0nq0epb2p8jen5gf6nhtt1

Повторяем для каждого пула.

Готово.

Ответить

Zerox28.02.2020 at 18:44
Да, все верно. Если виртуальным хостам нужна директория для сессий, то логично ее перенести в общую директорию с файлами виртуального хоста. Я обычно делаю директорию для php_sessions рядом с директориями www и logs. Путь к этой директории указывается в настройках php-fpm пула. Я делаю об этом пометку в своей новой статье по настройке web сервера на centos 8 - https://serveradmin.ru/nastrojka-web-servera-nginx-php-fpm-php7-na-centos-8/.

Текущая статья уже не будет обновляться ввиду устаревания системы, на базе которой она построена.

Ответить

Иван14.03.2020 at 20:15
Сразу не увидел, этот комментарий, но столкнулся, с этой проблемой также. Вроде решил благодаря поправки от Антона. Статья очень полезная, лучше бы обновить по возможности.
Спасибо.

Ответить

Антон26.02.2020 at 17:48
Добрый день, у меня не получилось, вернее сначала я настроил по вашей инструкции zabbix сервер, потом понадобилось поднять внутренний корпоративный портал, но после всех манипуляций из данной статьи и заббикс перестал работать и не открывается ничего, при этом все службы запущены и ошибок нет, я не устанавливал ssl сертификаты ибо они мне не нужны на внутреннем сайте, скажите нет ли инструкции для создания корпоративного сайта, или как показывать несколько внутренних доменов с одного веб сервера, в вашей инструкции описывается ситуация для внешнего веб сервера, а что если нужен внутренний?

Ответить

Zerox26.02.2020 at 17:50
Внутренний сайт ничем принципиально не отличается от внешнего.

Ответить

Антон26.02.2020 at 17:57
Скажите , а это вообще реально чтобы работал и заббикс и еще сайты с одного сервера или лучше отдельные делать?

Ответить

Zerox26.02.2020 at 18:01
Вполне реально. Никаких проблем с этим нет. Web интерфейс заббикса это по сути обычный сайт.

Ответить

Антон26.02.2020 at 18:09
Я так понимаю проблема как раз в файлах конфигурации nginx, так как в статье про настройку заббикса конфиг прописывается в /etc/nginx/conf.d/default.conf
а в этой инструкции создаются еще 2 конфига для сайта и PMA. Подскажите в моем случае нужно создать еще один конфиг под заббикс и что делать с дефолтным конфигом.
И второй вопрос, если у меня внутренний DNS на Windows Server что мне нужно сделать чтобы сеть узнала что по определенному серому IP работают 3 разных сервиса(Zabbix, site.loc, PMA)?

Ответить

Роман14.02.2020 at 22:42
Запускаю генерацию сертификата, по окончании выдаёт ошибку...Сертификаты не генерируются.
Объясните пожалуйста, толком что ему нужно, и что, где прописать. Так понимаю нужно прописать записи. Но где, в каких файлах их надо прописывать?
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about our work
encrypting the web, EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: N
Please enter in your domain name(s) (comma and/or space separated) (Enter 'c'
to cancel): zametkin.in.ua
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for zametkin.in.ua
Waiting for verification...
Challenge failed for domain zametkin.in.ua
http-01 challenge for zametkin.in.ua
Cleaning up challenges
Some challenges have failed.

IMPORTANT NOTES:
- The following errors were reported by the server:

Domain: zametkin.in.ua
Type: dns
Detail: DNS problem: NXDOMAIN looking up A for zametkin.in.ua -
check that a DNS record exists for this domain
- Your account credentials have been saved in your Certbot
configuration directory at /etc/letsencrypt. You should make a
secure backup of this folder now. This configuration directory will
also contain certificates and private keys obtained by Certbot so
making regular backups of this folder is ideal.

Ответить

Zerox15.02.2020 at 10:00
У вас не настроены dns записи для домена, на который сертификат заказываете. Это настраивается не на web сервере, а там, где у вас dns зона хостится.

Ответить

Роман14.02.2020 at 22:20
Подскажите пожалуйста, как, где, в каком файле прописывать A/AAAA и другие записи...Веб-сервер виртуальная машина, развёрнутf на гипервизоре, на ос CentOS 7, Debian 9

Ответить

Zerox15.02.2020 at 10:01
DNS настраивается на dns хостинге.

Ответить

Роман15.02.2020 at 11:50
Объясните пожалуйста, ещё лучше напишите по этому вопросу статью...
Я так понимаю, кроме зарегистрированного доменного имени, домена и развёрнутого сервера, нужно ещё получить так называемый хостинг, посоветуйте пожалуйста хостинг с бесплатным тестовым периодом...
К примеру зарегистрировал тестовый хостинг, возникает вопрос как, что и где прописывать на хостинге, те же самые записи и как развёрнутый сервер будет знать о существовании хостинга, и как они объединяются друг с другом, доменное имя (домен), хостинг, развёрнутый сервер.
Хотелось бы разобраться в этом деле, с фотографиями, например через личные сообщения, или через вайбер, телеграмм, электронную почту.

Ответить

Zerox15.02.2020 at 12:08
Информации по работе dns в интернете много. Не вижу смысла дублировать. Вам по сути надо сделать A запись в DNS и назначить вашему доменному имени ip адрес вашего хостинга. Управлять dns записями обычно можно там же, где выкупили доменное имя.

Ответить

Роман16.02.2020 at 03:05
Уже сделал A записи и назначил доменному имени ip адрес, в итоге одно и тоже...
Давайте на какой-то ресурс сброшу Вам скриншоты, там где я делал и назначал

Ответить

Дмитрий15.01.2020 at 05:18
Скажите, что это такое

hl.zeroxzed.ru
p1m2a.zeroxzed.ru ??

Это домен сайта имеется ввиду? Т.е. domen.com и domen2.com? Просто написано под два отдельных сайта для примера?

Ответить

Дмитрий15.01.2020 at 05:24
Или должно быть hl.domen.com - это http, а p1m2a.domen.com для https?

Ответить

Дмитрий15.01.2020 at 07:07
Первый пример для сайта, второй для phpmyadmin, там же все понятно написано.

Ответить

Дмитрий15.01.2020 at 07:11
Собирал себе все по этому мануалу, все прекрасно работает.
Отличная инструкция. Единственное не настроил чтобы работало, по https, и внутри и снаружи, приходиться при обновлении сертификата Letsencrypt ручками копировать сертификат во внутрянку. Но это уже надо как то автоматизировать через скрипты.

Ответить

Дмитрий15.01.2020 at 07:17
Ну и php уже конечно новая 7.3. Но обновляется все просто.

Ответить

Дмитрий15.01.2020 at 19:27
Может и понятно, мне момент непонятен. Мне кажется, лучше спросить, пусть даже вопрос будет глупый, чем бездумно копировать команды

Ответить

Zerox15.01.2020 at 08:33
Это имена доменов.

Ответить

Дмитрий15.01.2020 at 19:22
Меня интересует что такое hl и p1m2ma? Это должно быть до домена или это для примера и должен быть просто домен?

Ответить

Дмитрий15.01.2020 at 19:23
p1m2a, опечатался

Ответить

Zerox15.01.2020 at 20:05
Вместо hl.zeroxzed.ru должно быть ваше название домена, например site.ru или что-то еще.
В данном случае это просто имя домена, оно может быть любым, с одним или несколькими поддоменами, например tes.dev.site.ru или msk.site.ru.

Ответить

Дмитрий15.01.2020 at 20:21
Тогда как отдельный конфиг получить для phpmyadmin? Это будет один конфиг, получается? Если не будет поддомена?

Ответить

Дмитрий15.01.2020 at 19:31
На сколько я понял, hl и p1m2a - это обозначены два хоста для двух разных сайтов?

Ответить

Дмитрий15.01.2020 at 19:33
Т.е. должно выглядеть

server {
listen 80;
server_name domen.com;
root /web/sites/domen.com/www/;

А не

server {
listen 80;
server_name hl.domen.com;
root /web/sites/hl.domen.com/www/;

?

Ответить

Дмитрий15.01.2020 at 20:11
и, собственно, wordpress я должен скачать в /var/www/hl.domen.com/www/$файлы_вордпресс и он откроется по адресу domen.com, без www? или нужно писать hl впереди, но сайт все равно откроется по адресу domen.
com?

Ответить

Романыч21.09.2019 at 19:50
Здравствуйте, подскажите, пожалуйста, вылезла ошибка вот такая:
# nginx -t
# nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/site.ru/fullchain.pem": BIO_new_file() failed (SSL: error:02001002:system library:fopen:No such file or directory:fopen('/etc/letsencrypt/live/site.ru/fullchain.pem','r') error:2006D080:BIO routines:BIO_new_file:no such file)
nginx: configuration file /etc/nginx/nginx.conf test failed

Что делать?

Ответить

Zerox21.09.2019 at 20:45
Так написано же:

No such file or directory

У вас по адресу /etc/letsencrypt/live/site.ru/fullchain.pem нет сертификата.

Ответить

неважно06.10.2019 at 01:43
туфта какая то, мало того, что нужно 2 домена? так по написанным действиям нифига не генерится, а когда автору на это указывают переводит написанное.. зря только время потерял.

Ответить

Zerox06.10.2019 at 16:32
Я так понимаю, вариант, что ты сам не смог разобраться, не рассматривается вообще?

Ответить

Роман18.09.2019 at 18:28
Добрый день!!!
Пытаюсь поставить сервер по вашей статье, но не получается после # systemctl start nginx пишет ошибку: Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
Подскажите, пожалуйста, что делать? как решить данную проблему?

Ответить

Роман18.09.2019 at 18:33
Вот это пишет
# systemctl status nginx.service

● nginx.service - nginx - high performance web server
Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
Active: failed (Result: exit-code) since Ср 2019-09-18 15:17:41 GMT; 12min ago
Docs: http://nginx.org/en/docs/
Process: 10228 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=1/FAILURE)

сен 18 15:17:38 123 nginx[10228]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address...use)
сен 18 15:17:39 123 nginx[10228]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address...use)
сен 18 15:17:39 123 nginx[10228]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address...use)
сен 18 15:17:40 123 nginx[10228]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address...use)
сен 18 15:17:40 123 nginx[10228]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address...use)
сен 18 15:17:41 123 nginx[10228]: nginx: [emerg] still could not bind()
сен 18 15:17:41 123 systemd[1]: nginx.service: control process exited, code=exited status=1
сен 18 15:17:41 123 systemd[1]: Failed to start nginx - high performance web server.
сен 18 15:17:41 123 systemd[1]: Unit nginx.service entered failed state.
сен 18 15:17:41 123 systemd[1]: nginx.service failed.
Hint: Some lines were ellipsized, use -l to show in full.

Ответить

Zerox18.09.2019 at 20:38
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address…use)

У вас на 80-м порту уже кто-то работает. Наверно apache.

Ответить

Роман19.09.2019 at 19:01
Спасибо за ответ!
А у Вас случайно нет пошаговой инструкции по настройки сервера?
Что-то у меня совсем не хватает мозгов соединить все во едино, то с одного места взять надо кусок, то с другого места кусок. В итоге не работает ни чего.
Уже голова кругом идет...
Может есть все-таки инструкция для недоделанных "админов"?

Ответить

Zerox19.09.2019 at 20:35
У меня целая куча инструкций на сайте. Одну из них вы комментируете. Какая конкретно инструкция нужна? На сайте нормально работает поиск, можно найти.

Ответить

Kvin15.09.2019 at 16:46
У меня не видит phpmyadmin в браузере ошибка 404 по пути p1m2a.site.ru/phpmyadmin. И root в usr/share/phpmyadmin не видит содержимого...В чем может быть дело? С правами на папку phpmyadmin...стоят 0755, вроде должно видеть...

Ответить

Zerox16.09.2019 at 10:15
Проверяйте конфиги, посмотрите лог ошибок веб сервера. Там можно найти подсказку, почему 404 ошибка выходит. Если напутали что-то с путями, то сразу будет видно по запросу с ошибкой.

Ответить

Аноним16.09.2019 at 14:58
Вчера переустановил php-fpm и phpmyadmin, заработало все...вчера остановил nginx, сегодня запустил и не работает даже основной site.ru, на нем ошибка 403. Переустановка php-fpm не помогает. В логах подсказки нет, просто "GET / HTTP/2.0" 403

Ответить

Kvin16.09.2019 at 21:04
Похоже на то, что главный конфигурационный файл nginx.conf не загружается...перезапустил nginx и сервер перезагружал, ничего не помогло. Может у кого такое было? Как можно принудительно загрузить nginx.conf? Selinux отключен.

Ответить

Дмитрий06.09.2019 at 05:47
Добрый день все получилось, но в phpmyadmin висит "В конфигурационном файле необходимо задать парольную фразу (blowfish_secret)"
Не понимаю в каком файле нужно это прописать? В самой директории конфига phpmyadmin не вижу.

Ответить

Zerox06.09.2019 at 08:19
В config.inc.php надо добавить:

$cfg['blowfish_secret'] = 'dfgfhghfgddgffdsggf';

Ответить

Дмитрий06.09.2019 at 08:43
Это понятно но где он находиться? в самой папке phpmyadmin что прилинковали его нет, тот что в /etc/phpmyadmin прописываю не работает.

Ответить

Zerox06.09.2019 at 09:37
В общем случае в /etc/phpMyAdmin. Возможно у веб сервера нет туда доступа, поэтому он не использует конфиг, а работает с дефолтными настройками.

Ответить

Дмитрий06.09.2019 at 10:02
Ага ставил все по инструкции. помогла смена владельца спасибо.
chown nginx:nginx /etc/phpMyAdmin/config.inc.php

Ответить

Антон Зеленко26.08.2019 at 22:40
Спасибо большое за статью. Получилось на CentOS 7 установить и скомпилировать с rtmp-module-master NGINX 1.16.1 , php7.1, mariadb 10.4 , а также phpmyadmin. Все это должным образом настроить и в итоге получился сайт ретрансляций 380tv.ru

Раньше сервер работал и на Ubuntu-18.04 и на Opensuse leap 15.1,
но должным образом настроить веб-сервер ретрансляций на ноутбуке не удавалось. Поэтому начал осваивать CentOS 7

Ответить

anton04.07.2019 at 13:22
Добрый день!
Столкнулся с ошибкой:

nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/t1.site.ru/fullchain.pem": BIO_new_file() failed (SSL: error:02001002:system library:fopen:No such file or directory:fopen('/etc/letsencrypt/live/t1.site.ru/fullchain.pem','r') error:2006D080:BIO routines:BIO_new_file:no such file)
nginx: configuration file /etc/nginx/nginx.conf test failed
Как я понял он не видит сертификата для моего phpmyadmin - t1.site.ru
Попытался сделать сертификат на него - тоже ошибка.

Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 1
Plugins selected: Authenticator standalone, Installer None
Starting new HTTPS connection (1): acme-v02.api.letsencrypt.org
Please enter in your domain name(s) (comma and/or space separated)  (Enter 'c'
to cancel): t1.sait.ru
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for t1.sait.ru
Waiting for verification...
Challenge failed for domain t1.sait.ru
http-01 challenge for t1.sait.ru
Cleaning up challenges
Some challenges have failed.

IMPORTANT NOTES:
 - The following errors were reported by the server:

   Domain: t1.sait.ru
   Type:   connection
   Detail: Fetching
   http://t1.sait.ru/.well-known/acme-challenge/su-5OO9dv2hmakrn0PKhLNxijyoBaa7J6pGOC1ZP05w:
   Timeout during connect (likely firewall problem)

   To fix these errors, please make sure that your domain name was
   entered correctly and the DNS A/AAAA record(s) for that domain
   contain(s) the right IP address. Additionally, please check that
   your computer has a publicly routable IP address and that no
   firewalls are preventing the server from communicating with the
   client. If you're using the webroot plugin, you should also verify
   that you are serving files from the webroot path you provided.
dns записи созданы и отрабатывают.
Прошу помощи с настройкой nginx.

Ответить

Zerox04.07.2019 at 13:47
Вы сертификат не получили. В ошибке же явно написано:
Timeout during connect (likely firewall problem)
Сервис lets encrypt не может подключиться к вашему серверу, чтобы подтвердить выпуск сертификата.

Ответить

anton04.07.2019 at 15:38
Спасибо. Да, фаервол закрыл 80 порт для сервиса.

Ответить

vsvs20.06.2019 at 05:36
к сожалению, описанный в данной статье способ доступа к сайту по sftp, лично у меня не сработал (apache, opencart), т.к. в моем случае необходимо, чтобы для директории сайта владелец и группа были: apache, а в статье владельцем и группой является пользователь + в его группу добавляется apache, таким образом, apache не является ВЛАДЕЛЬЦЕМ, и возникают ошибки при работе сайта. А сделать одновременно владельцем каталогов и ПОЛЬЗОВАТЕЛЯ и APACHE не получается - или есть такой вариант?

Ответить

Zerox20.06.2019 at 11:18
Как минимум, можно apache запустить от другого пользователя - владельца каталога. Это настраивается в конфиге апача. Разницы нет, от какого пользователя он работает. Важно только потом владельца файлов сайта поменять на нужного пользователя.

Ответить

vsvs25.07.2019 at 06:16
Спасибо за ответы, но как всегда при решении одних задач появляются новые ;-). Если запускать apache от отдельного пользователя (для отдельного сайта) как тогда создавать следующего пользователя (для следующего сайта) - для него apache как будет работать, запускаясь от первого пользователя? Поиск выдал модуль mpm-itk, позволяющий работать apache отдельно для каждого пользователя/группы - все вроде хорошо, в том числе и безопасность повышается, но с другой стороны этот модуль не потоковый, и возможны тормоза на сайтах. Можете как-то это прокомментировать или предложить еще решение?

Ответить

Вячеслав05.06.2019 at 16:20
Здравствуйте. Статья отличная. Прям любимая шпаргалка!
Не нашел или не увидел статью http mpm-event + php-fpm + http/2
Хотелось бы такую )))
Я склонен к такой версии потому что в реальности mpm-event + php-fpm = nginx + php-fpm
Или разница минимальна, но в конечном счете ноль проблем с любой платформой.
Ну и никаких костылей для .ht и прочего )

Ответить

Zerox05.06.2019 at 16:25
Интересная мысль, не пробовал такую связку. По моей практике, с apache мне приходится сталкиваться только на сайтах с bitrix. Но там у них готовое bitrixenv, самому ничего настраивать не надо. А все остальное уже отлично работает без apache.

Ответить

Вячеслав05.06.2019 at 17:12
Тут на мой взгляд все просто. В apache давно стояла задача уменьшения нагрузок и поедание памяти. И лет 5 как вопрос активно разрабатывался и с версии apache 2.4.17 (если не забыл) все давно решено и работает в ветке stable. А производительность в сравнении в боевом режиме не имеет отличий (на мой субъективный взгляд, ну и есть прослойка людей которая считает так же). Конечно не могу судить однозначно о производительности, но думаю из коробки такой вариант лучше, хотя есть нюансы. Впрочем отличия от nginx минимальные, тот же сокет fpm, тот же по сути вариант обработки php, основной момент это процесс который не надо закрывать перезапускать и он работает. Итог малое потребление памяти, ресурсов процессора и отдача статических страниц без загрузки PHP и сопутствующих библиотек. Все как у nginx )))

Ответить

Zerox05.06.2019 at 17:50
Вот именно, все как у nginx, но ведь уже и так есть nginx :) Я лично привык к нему, к его конфигам, locations, синтаксису и т.д. Apache для меня уже как темный лес.

Ответить

Вячеслав05.06.2019 at 18:10
Ну тут увы ))) мы (профессия админа) работаем на людей и чаще не мы выбираем какие плюшки ставить а люди и задачи. Просто как пример. Я раньше сидел на варианте apache+nginx и плевал с высокой башни потом пересел на чистый nginx (это все конечно в самых лучших традициях ускорения сжатия и прочего). И тут однажды вдруг понял апач это отлично и прямо из коробки и ноль головной боли запустил --> один конфиг --> один сайт и все. Привычка да хорошо, но гибкость решений мне кажется тоже не плохо )))

Ответить

Dan23.05.2019 at 07:41
Спасибо за статью. Сертификат для поддомена с PhpMyAdmin включается в основной сертификат (expand), или создаётся отдельный? И как лучше с точки зрения безопасности?

Ответить

Zerox23.05.2019 at 15:15
Я всегда отдельные делал. Привык с тех времен, когда let's encrypt выдавал только на конкретные домены сертификат.

Ответить

Zerox09.05.2019 at 19:46
Не совсем понял вопрос. Отключить можно, но в чем суть вопроса?

Ответить

vsvs11.05.2019 at 07:35
Если ответ был на мой вопрос - поясняю, в чем была суть. При установке сертификата от LE с помощью cerbot по умолчанию устанавливается редирект с http на https. Но дело в том, что, например, при переносе сайта, некоторые файлы (папки) должны открываться не только по https, но и по http. Поэтому удобнее настраивать редирект с http на https лучше в .htaccess для соответствующего сайта с необходимыми исключениями. Если оставить редирект при установке от LE и даже потом убрать строчки для редиректа в конфиге апаче, страницы сайта, у меня по крайней мере НЕ ОТКРЫВАЛИСЬ без https - настроенный на автоматический редирект сертификат не позволял этого. Но я вроде уже нашел ответ у разработчика, хотя еще не успел проверить - вроде можно опционально задать в запросе сертификата через --no-redirect (или устанавливать сертификат через плагин апаче - там вроде тоже задается вопрос о редиректе).

Ответить

Zerox11.05.2019 at 09:45
Вы что-то путаете. Let's encrypt это просто сертификаты. Они к редиректам не имеют никакого отношения. Редирект настраивается в веб сервере - nginx, apache. Если вам не нужен редирект, то отключите его в настройках веб сервера или .htaccess.

Но нужно учитывать еще один момент. Все современные браузеры сами автоматически обращаются к сайту по https. Зайдя один раз на сайт и увидев, что там настроен https, они будут обращаться только по нему. Исключение только старый браузер IE.

Так что я рекмоендую вам все переводить на https. Без него банально скоро браузеры перестанут вообще открывать сайты.

Ответить

vsvs11.05.2019 at 16:50
По поводу необходимости все переводить на https - это все понятно. Вопрос в другом - мне, конечно, нужен https и все сайты будут на https, НО НЕКОТОРЫЕ страницы сайтов ДОЛЖНЫ ОДНОВРЕМЕННО открываться и через https и через http!
КАК реализовать эту задачу (пусть через конфиг апаче), чтобы при установленном сертификате настроить открытие всего сайта по https, а НЕКОТОРЫХ СТРАНИЦ ОДНОВРЕМЕННО и через https и через http?
Сам пытался это делать после установке сертификата LE (при этом по умолчанию редирект был как бы включен при запросе сертификата). А именно: удалял из конфига строчки:
Redirect permanent / https://site.ru/
…

Redirect permanent / https://site.ru/

делал редирект только в .htaccess - не получилось. Все работало или только по https или вообще не открывался сайт.

Ответить

Zerox12.05.2019 at 16:21
В свете текущего поведения браузеров, я не знаю, как это реализовать. На уровне веб сервера это можно сделать. Сайт без проблем может работать одновременно и по http, и по https. А что делать с браузерами, которые принудительно будут открывать именно https версию сайта?

Ответить

vsvs09.05.2019 at 19:20
можно ли при запросе сертификата LE отменить автоматический редирект с http на https на CENTOS

Ответить

Роман10.01.2019 at 14:58
Добрый день, я полный профан в веб серверах и во всем что с ними связанно. Нужна помощь, либо в литературе, что первым делом нужно изучить, либо в совете.
Куплен домен трали-вали.ru на хостинге http://www.jino.ru в настройках прописаны следующие DNS-записи.
*.трали-валиk.ru IN A 195.161.41.85 этот адрес был тут изначально.
трали-вали.ru IN A 90.150.52.230 внешний IP адрес от провайдера (Шлюз Centos7 с проброшенными портами 80, 443 на firewalld)
трали-вали.ru IN A 192.168.152.254 адрес Centos 7 на котором пытаюсь развернуть webserver по вашей инструкции.
трали-вали.ru IN CAA 0 issue letsencrypt.org
трали-вали.ru IN NS ns4.jino.ru - NS записи тоже были тут изначально.
трали-вали.ru IN NS ns1.jino.ru
трали-вали.ru IN NS ns2.jino.ru
трали-вали.ru IN NS ns3.jino.ru

когда выполняю команду tracert трали-вали.ru находит домен по IP 90.150.52.230, а не по IP webservera на котором пытаюсь получить сертификат от Let's Encrypt.
выполнив команду certbot certonly выдает ошибку:
Failed authorization procedure. трали-вали.ru (http-01): urn:ietf:params:acme:error:connection :: The server could not connect to the client to verify the domain :: Fetching http://трали-вали.ru/.well-known/acme-challenge/m5R4yTtkoKUxySlMg_N5rvVWmgqSOMDMNxx20uf8yJI: Connection refused

IMPORTANT NOTES:
- The following errors were reported by the server:

Domain: трали-вали.ru
Type: connection
Detail: Fetching
http://трали-вали.ru/.well-known/acme-challenge/m5R4yTtkoKUxySlMg_N5rvVWmgqSOMDMNxx20uf8yJI:
Connection refused

To fix these errors, please make sure that your domain name was
entered correctly and the DNS A/AAAA record(s) for that domain
contain(s) the right IP address. Additionally, please check that
your computer has a publicly routable IP address and that no
firewalls are preventing the server from communicating with the
client. If you're using the webroot plugin, you should also verify
that you are serving files from the webroot path you provided.

В

Ответить

Марат02.10.2018 at 11:57
Спасибо огромное!
Наконец-то я получил доступ к файлам сайта!

Ответить

2rage28.09.2018 at 09:20
Такая же проблема с php-fpm, не работает ни через сокеты, ни через tcp. Как исправить? Заранее спасибо

Ответить

Дмитрий06.09.2018 at 18:55
Проблема php-fpm самого сокета listen = /var/run/php-fpm/php-fpm.sock в директории нет

Ответить

Андрей13.08.2018 at 00:21
Статья хорошая, но по поводу sftp добавлю удобнее сделать такой конфиг sshd_config

Subsystem sftp internal-sftp
# используем группу sftp добавляем в нее всех пользователей один сайт - один пользователь
Match Group sftp
#указываем домашнюю директорию пользователя сайта
ChrootDirectory %h
AllowTCPForwarding no
ForceCommand internal-sftp

#Изменяем пользователю домашний каталог
usermod -d /web/sites/hl.zeroxzed.ru/www hl.zeroxzed.ru

#добавляем пользователя сайта в группу sftp
usermod -a -G sftp hl.zeroxzed.ru

Ответить

Zerox13.08.2018 at 08:10
Спасибо за замечание. Так действительно удобнее.

Ответить

Александр10.07.2018 at 07:30
Здраствуйте!
После nginx -t выдает ошибку:

nginx: [emerg] BIO_new_file("/etc/letsencrypt/live/site.ru/fullchain.pem") failed (SSL: error:02001002:system library:fopen:No such file or directory:fopen('/etc/letsencrypt/live/site.ru/fullchain.pem','r') error:2006D080:BIO routines:BIO_new_file:no such file)
nginx: configuration file /etc/nginx/nginx.conf test failed

Подскажите, что делаю не так?

Ответить

Zerox10.07.2018 at 11:55
У вас не существует сертификата по пути, который указан в конфиге. Он либо не получен, либо вы напутали с именами доменов или файлов.

Ответить

GreatORC24.07.2018 at 12:38
Добрый день!

Столкнулся с такой же проблемой.

Предполагаю, что ошибка возникает из-за того что сертификат мы делаем только для hl.zeroxzed.ru, а для p1m2a.zeroxzed.ru не делаем.
Возможно Вы забыли написать, что сертификаты нужно выпускать на все сайты, которые мы добавляем.

Сейчас проверю данный факт и отпишусь, что получилось

Ответить

GreatORC24.07.2018 at 13:02
Проверил, действительно, для каждого сайта необходимо отдельно запускать: "certbot certonly"

После этого "nginx -t" прошел без ошибок

Ответить

Аноним24.05.2018 at 20:40
Можно в предыдущем комментарии удалить адрес сайта? Спасибо

Ответить

Аноним24.05.2018 at 20:39
Этот гайд не учитывает SElinux, при старте nginx вываливается ошибка nginx: [emerg] open() "/web/sites/phpmy.ua/log/ssl-access.log" failed (13: Permission denied)

Ответить

GreatORC24.07.2018 at 18:35
Тут достаточно подробно описана настройка SELinux для nginx
https://www.nginx.com/blog/nginx-se-linux-changes-upgrading-rhel-6-6/.
Мне помогло.

Ответить

komron28.03.2018 at 18:11
остановить nginx httpd остановить?

Ответить

Zerox28.03.2018 at 18:33
systemctl stop nginx
systemctl stop httpd

Ответить

Владислав16.06.2018 at 00:50
У вас есть Centos 7 + LEMP под DLE?
Нигде не могу найти решения по нормальному отображению сайта без .htacces, реврайты ставил в конфиг сайта nginx, всё равно плохо работает, а при нажатии на страничку новости весь стиль слетает и путь у него получается некорректный.
Но на апачи всё нормально, так как mod_write там работает отлично..

Ответить

komron28.03.2018 at 18:10
как это кто-то работает не думаю с браузером связано а как остановить?

Ответить

komron28.03.2018 at 18:05
У меня локальная сеть состоит типа так, несколько ОС на CentOS
1) Есть Router имеет доступ в Интернет на с firewall проблем нету всё ОК, потому что Я на Vmware
2) Есть DNS сервер работает ОК добавил запис MX как Вы советовали
3) Есть Mail сервер делал по вашей статье Всё было ОК до бесплатных сертификатов.

4) Когда Я настраивал свои конфиги везде вместо вашего домена Я добавил свой домен example.com
5) Системы настроены так как Вы говорите, проблем нету
6) Даже пробовал просто подключить напрямую свой сервер то есть он находился не в локальки просто с NAT на vmware всё равно не сработало, если думать, что проблема с DNS

Ответить

komron28.03.2018 at 17:59
У меня во время запуска команды certbot certonly просит вводит e-mail вводил, а потом спрашивал ввести domain name вводил example.com выходит следующая ошибка
problem binding to port 80: could not bind to Ipv4 or Ipv6

Ответить

Zerox28.03.2018 at 18:02
В тексте ошибки все сказано. certbot хочет запустить временно веб сервер для проверки имени домена, но у вас на 80-м порту уже кто-то работает, либо nginx, либо httpd. Надо их остановить на время выпуска сертификата.

Ответить

mihonukr03.06.2019 at 00:05
Я думаю что у многих проблема именно в этом месте.
Допиши в статью что перед запуском команды certbot certonly
нужно остановить nginx, т.к. на пару абзацев выше ты написал
что nginx мы запускаем.

Ответить

Zerox03.06.2019 at 01:45
Так нет же, nginx не запустится без сертификата с тем конфигом, что мы ему ранее установили. Я даже указал это отдельно перед настройкой certbot. Если у кого-то nginx работает перед получением сертификата, значит он не по инструкции идет.

Ответить

Аноним28.03.2018 at 16:48
У меня проблема!
При настройки при создание сертификатов на шаг вводите ваш Домен вожу example.com говорит домен не работает

Ответить

Роман19.03.2018 at 20:17
Здравствуйте, подскажите а как правильно обновить версию phpmyadmin с учетом настроек в данной инструкции? Или обновление версии не потребует дополнительных манипуляций с файлами конфигурации PMA?

Ответить

Кирилл11.02.2018 at 11:04
Всеобъемлющая инструкция, попробую воспроизвести шаги и настроить должным образом сервер.
Спасибо!

Ответить

Evi1dark07.02.2018 at 09:28
Я что-то совсем запутался с location... Не могу никак понять как сделать чтоб phpmyadmin открывался не как отдельный виртуальный хост (как в статье вида p1m2a.site.ru), а как site.ru/phpmyadmin. Перепробовал разные location, пробовал через alias, пробовал еще через что-то - по при открытии страницы somesite.ltd/phpmyadmin у меня открывается index.php из каталога web/somesite.ltd/www... Подскажите, пожалуйста, как сделать чтоб открывался phpmyadmin через somesite.ltd/phpmyadmin.
Еще заметил что при генерации сертификата, следуя по порядку по статье - вылетала ошибка при генерации, вылечилось остановкой nginx...

Ответить

Zerox07.02.2018 at 10:31
1. Если не нужен отдельный виртуальный хост для phpmyadmin, то можно его просто положить в любую папку на существующем хосте и зайти в эту папку. То есть положить в /web/somesite.ltd/www/pma и зайти потом в браузере в somesite.ltd/pma
Phpmyadmin это просто набор php скриптов. Их как угодно можно использовать и запускать. Можно отдельным виртуальным хостом, можно алиасом, а можно просто в папку любую положить и пользоваться. Только желательно доступ к этой папке закрыть через htaccess или назвать так, чтобы не подобрал никто.

2. Если при генерации сертификата помогла остановка nginx, значит в качестве подтверждения был выбран способ через запуск временного веб сервера, но он не смог запуститься, из-за того, что 80-й порт на сервере занимал запущенный nginx. Об этом будет сказано в ошибке. Тогда остановка nginx помогает.

Ответить

Evi1dark07.02.2018 at 13:14
Мдееее... Как говориться "все гениальное просто"... Положил папку в somesite.ltd/www и заработало...
Странно, но почему не получалось сделать через алиас? Столько форумов перерыл, по разному пробовал - но ничего не работало...
Спасибо огромное за статьи (сам только осваиваю это все) и за подсказки.

Ответить

Evi1dark09.02.2018 at 16:09
Подскажите плиз, куда копать - я уста рыть форумы... Как сделать через alias?
Нарисовал следующее:
location /pma {
alias /usr/share/phpMyAdmin/;

location ~ /(libraries|setup) {
return 404;
}

location ~ ^/pma/(.*\.php)$ {
alias /usr/share/phpMyAdmin/$1;
fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
fastcgi_index index.php;
include fastcgi_params;
fastcgi_param SCRIPT_FILENAME $request_filename;
}
location ~* ^/pma/(.*)\.(jpg|jpeg|gif|png|css|zip|tgz|gz|rar|bz2|doc|xls|exe|pdf|ppt|tar|wav|bmp|rtf|swf|ico|flv|txt|docx|xlsx)$ {
alias /usr/share/phpMyAdmin/$1;
}
}

Подгружается, открывается, работает - но нет ни одной картинки :( уже 2-й день мучаюсь - через папку то норм все получилось, но вот как добиться через alias? Уже чуть ли не спортивный интерес... Конфиг использовал который в статье для основного хоста.

Ответить

Evi1dark10.02.2018 at 03:18
Кажется разобрался... Скобочку не туда поставил.

Ответить

Zerox11.02.2018 at 23:47
Я вообще алиасы не использую в nginx. Нет ни одного рабочего конфига под рукой. Я все виртуальными хостами обычно делаю, или в папку отдельную кладу. Я не вижу смысла в алиасах.

Ответить

Evi1dark13.02.2018 at 11:55
Ну я просто до этого с nginx не работал, поэтому вот было интересно как реализовать можно :)
Спасибо за инструкцию и подсказки.

Ответить

work23.02.2018 at 00:24
Создал виртуальный хост как у вас hl.zeroxzed.ru.
Положил туда ссылку на phpmyadmin.
Ругается на права доступа к сессиям ...
Т.е получается сессии у нас nginx:nginx, а сокет php запущен под hl.zeroxzed.ru:hl.zeroxzed.ru.

Вопрос решается если юзера hl.zeroxzed.ru добавить в группу nginx, но ведь это не выход ...

Ответить

sevo4410.11.2017 at 00:57
Доступ к сайту по sftp -- хорошо расписан. Возьму именно этот вариант на вооружение. Раньше пробовал подобное реализовать но не выходило. Понял где я не так делал. ProFTP с доступом по пользователям с файла хорошо работает, но настраивать дольше и периодически сюрпризы с настройкой в новой версии ProFTP.

Ответить

Борис28.10.2017 at 13:50
вместо mkdir -p /web/sites/hl.zeroxzed.ru/www && mkdir /web/sites/hl.zeroxzed.ru/log
удобнее mkdir -p /web/sites/hl.zeroxzed.ru/{www,logs}

Ответить

Zerox28.10.2017 at 16:25
Да, так удобнее.

Ответить

sevo4410.11.2017 at 01:00
Отдельный респект за отзыв. Предполагал что можно проще команду писать и вот увидел.

Ответить
Добавить комментарий
Ваш адрес email не будет опубликован.

Комментарий


Имя


Email


Сайт


Отправить комментарий
Подписка на новые комментарии:

Отправить уведомление только при ответе на мой комментарий

Нажимая кнопку "Отправить комментарий" Я даю согласие на обработку персональных данных.
 
	Дешевые дедики от Selectel, есть посуточная оплата. Использую сам.
Ссылки
	Админский канал: t.me/srv_admin
	Админский чат: t.me/srv_admins
	Мой канал: youtube.com/user/zeroxzed
 
Группа Вконтакте
	Системное администрирование

Анонс статей (без спама)
 Подписаться
Прикольная игра

Популярное

Как настроить микротик routerboard RB951G-2HnD
Написано: 21.11.2018 940,687

CentOS 7 и 8 настройка сервера после установки
Написано: 05.10.2019 629,037

Сетевые настройки в CentOS 8, 7
Написано: 17.10.2019 625,166

Asterisk - SIP АТС для офиса, пошаговая инструкция по настройке с нуля
Написано: 03.03.2020 442,153

Настройка iptables в CentOS 7
Написано: 18.10.2015 346,790
 
Вход/Регистрация




Log in  Remember Me
Регистрация
Lost your password?
Статистика

Соглашение
Политика конфиденциальности
Свежие записи

Мониторинг списка запущенных процессов в Zabbix
Написано: 22.12.2020

WebPageTest - локальная установка и настройка приватного сервера тестирования скорости сайта
Написано: 17.12.2020

Установка Zabbix на Astra Linux
Написано: 15.12.2020

Пример нагрузочного тестирования сайта с Yandex.Tank
Написано: 06.12.2020

Отзыв на Getscreen.me - сервис удаленного управления компьютерами через браузер
Написано: 02.12.2020
Комментарии
Юрий: Подскажите. Какую именно галочку?...
Zerox: Ни разу не видел такой реакции на запуск openvpn сервера. Может с маршрутами в к...
Кирилл: Здравствуйте, с наступающим Вас! Возможно в комменте эта ситуация обсуждалась, и...
Андрей: Владимир, приветствую. Дополни свою статью, Обязатлеьно перед запуском консоли v...
: по дефолту мимо всё, пробовал поправить ^authentication failure под себя не могу...
