#!/bin/bash

##==========SSH.ED25519.sh==========##

function variable {
##=======≠==========================
##	Parametru
	COMKEY="$MAILKEY";
	#$ COMKEY="$USER"
	#$ NKEY=
	#$ PASSKEY="";
	#$ TKEY=rsa;BKEY=2048;
	#$ TKEY=dsa;BKEY=1024;
	#$ TKEY=ecdsa;BKEY=256;
	#$ TKEY=xmss;BKEY=2048;
	TKEY=ed25519;BKEY=2048;
	HOST=$(hostname -s);
	HOSTIP=$(hostname -i);
	NKEY="$ID"."$TKEY";
	DKEY=~/.ssh/"$ID"."$HKEY"$NKEY".key"

}



##=======================================
## ДАННЫЕ
##
echo "Имя ключа:";
read NKEY;

# echo "Введите E-Mail: ";
# read MAILKEY;

echo "Пароль к ключу:";
read PASSKEY;

#$ echo "Тип Шифрование :  "; reed TKEY;
#$ echo "Уровень шифрования: "; reed BKEY;

# func init
variable

##=======================================
###  -Проверка папки ~/.ssh
echo "## -Find folder: ~/.ssh ";
	if [ -d ~/.ssh ]; then
		echo "Directory already exists"
else
	echo "NO EXISTS"
	mkdir $HOME/.ssh

fi


##=======≠==========================
## Add ssh key
##
ssh-keygen -t "$TKEY" -b "$BKEY" -f "$DIRKEY" -C "$COMKEY" -N "$PASSKEY"


##=============≠=================
## REG key
# ssh-copy-id -i ~/.ssh/"$NAMEKEY".pub "$USER"@"$HOSTIP" ;


##=============≠=================
## SSH-AGENT
eval "$(ssh-agent -s)";


##=============≠=================
## ADD KEY
ssh-add ~/.ssh/"$NAMEKEY";
# ssh "$USER"@"$HOSTIP";

exit


##=======≠==========================
## ПРИМЕР СТРОЧКИ 
##
## ssh-keygen -t ed25519 -b 2048 -f "~/.ssh/id_ed25519.key" -C "mymail@site.com" -N "MYPASS"

## eval "$(ssh-agent -s)";
## ssh-add ~/.ssh/id_ed25519
## ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.10