#!/bin/bash sshrsa.sh

function variable {
	PASS="";
		#$ TKEY=rsa;
	TKEY=dsa;
		#$ TKEY=ecdsa;
		#$ TKEY=xmss;
		#$ TKEY=ed25519
	HOST=$(hostname -s);
	HOSTIP=$(hostname -i);
	DKEY=$HOME/.ssh/"$NAME"_"$TKEY" ;

}

### ВВДИВОДИМЫЕ ДАННЫЕ ###
#
echo "Введите название ключа: "; read NAME;
#$ echo "Введите пароль к ключу: "; read PASS;
#$ echo "Тип шифрования ключа :  "; reed TKEY;
#$ echo "Сколько бит шифрования: "; reed BKEY;
#
##########################

# func init
variable


###  -Проверка папки- ###
echo "## -Find folder: $HOME/.ssh ";
	if [ -d $HOME/.ssh ]; then
		echo "Directory already exists"
else
	echo "NO EXISTS. Create $HOME/.ssh "
	echo
	mkdir $HOME/.ssh

fi
#########################

echo "### -Создаем ключ $TKEY в папке $DKEY ###";
#### sh-keygen -t dsa -b 1024 -f ~/.ssh/id_dsa -C root -N "";

ssh-keygen -t "$TKEY" -b "$BKEY" -f $HOME/.ssh/"$NAME"_"$TKEY" -C "$USER" -N "$PASS";

ssh-copy-id -i "$DKEY".pub "$USER"@"$HOSTIP" ;
ssh-add "$DKEY" ; 

echo "#######  connect $HOSTIP   ########";
ssh "$USER"@"$HOSTIP";
exit 1 ;
echo "Authentific $HOSTIP -GOOD-"; 

echo "### -END- ###";
exit
