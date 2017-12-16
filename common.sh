#!/bin/bash

check_root () {

	if [ "$UID" -ne "0" ]
        then
                echo "Vous devez être administrateur. Fin du script."
                exit 1
fi

}

check_ping () {

	if ! ping -c 1 -W 1 $1 &> /dev/null
    then
    echo "$1 est injoignable"
    exit 1
fi

}

confirm_it () {
        read -p 'confirmez (Y/N) :' -n 1 answer
        case $answer in
                        [yYoO]*) echo "OK
                        "
                        return 0
                        ;;
                        [nN]*) exit 1
                        ;;
                        *) echo "Erreur de saise"
                        confirm_it
                        ;;
        esac
}

check_csv_net.common () {
for vm in `cat $1`
  do
		host=$(echo $vm | cut -d ";" -f1)
    net_vm=$(echo $vm | cut -d ";" -f4)
    if ! grep -e $net_vm $2 1>/dev/null
    then
      echo "$vm ne fait partie d'aucun réseau"
      return 1
    fi
		dooble=$(grep -e ${host} ${1} | wc -l)
		if [[ ${dooble} > 1 ]]
		then
			echo "une ou plusieurs machines ont le même nom"
			return 1
		fi
  done
}


verif_ip () {
  echo "****************************

L'ip à tester de $5 est $1 avec un masque $2 sur le réseau $3 $4"

  vm_1=$(echo $1 | cut -d "." -f1)
  vm_2=$(echo $1 | cut -d "." -f2)
  vm_3=$(echo $1 | cut -d "." -f3)
  vm_4=$(echo $1 | cut -d "." -f4)

  firstip=$(ipcalc -b $3/$2 | grep HostMin | cut -d " " -f4)
  lastip=$(ipcalc -b $3/$2 | grep HostMax | cut -d " " -f4)

  first1=$(echo $firstip | cut -d "." -f1)
  first2=$(echo $firstip | cut -d "." -f2)
  first3=$(echo $firstip | cut -d "." -f3)
  first4=$(echo $firstip | cut -d "." -f4)

  last1=$(echo $lastip | cut -d "." -f1)
  last2=$(echo $lastip | cut -d "." -f2)
  last3=$(echo $lastip | cut -d "." -f3)
  last4=$(echo $lastip | cut -d "." -f4)

  echo "La première ip du réseau est : $firstip"
  echo "Le dernière ip du réseau est : $lastip"
  #echo "Votre ip est $1"
	#on procédera octet par octet -> rendre tout cela plus élégant serait un plus.
  if [ $vm_1 -ge $first1 ] && [ $vm_1 -le $last1 ] && \
  [ $vm_2 -ge $first2 ] && [ $vm_2 -le $last2 ] && \
  [ $vm_3 -ge $first3 ] && [ $vm_3 -le $last3 ] && \
  [ $vm_4 -ge $first4 ] && [ $vm_4 -le $last4 ]
  then
echo "
l'ip $1 de $5 est conforme au réseau souhaité.

**************************** "
  else
    echo "l'ip $1 de $5 est non conforme à $4."
    return 1
  fi
}


dhcp_calc () {

  firstip=$(ipcalc -b $1/$2 | grep HostMin | cut -d " " -f4)
  lastip=$(ipcalc -b $1/$2 | grep HostMax | cut -d " " -f4)

  first1=$(echo $firstip | cut -d "." -f1)
  first2=$(echo $firstip | cut -d "." -f2)
  first3=$(echo $firstip | cut -d "." -f3)
  first4=$(echo $firstip | cut -d "." -f4)

  last1=$(echo $lastip | cut -d "." -f1)
  last2=$(echo $lastip | cut -d "." -f2)
  last3=$(echo $lastip | cut -d "." -f3)
  last4=$(echo $lastip | cut -d "." -f4)
#le dernier octet de la carte virtuelle a normalement la valeur 1, on ajoutera donc 1 à  dernier octet l'ip minimale distribuée pour que les deux adresses ne rentrent pas en conflit

dhcp_min="${first1}.${first2}.${first3}.$(expr $first4 + 1)"
dhcp_max="${last1}.${last2}.${last3}.${last4}"


}

mb2gb () {
    local -i mbytes=$1;
    if [[ $mbytes -lt 1048576 ]]; then
        echo "$(( (mbytes + 1023)/1024 ))MB"
    else
        echo "$(( (mbytes + 1048575)/1048576 ))GB"
    fi
}
check_disk () {
        duse=0
        dusesum=0
        # selon l'hyperviseur, les disques peuvent prendre l'appellation vda ou sda. On recherche alors les deux.
        dfree=`df -lh | grep "sda\|vda" | awk ' { print $4 } '`
        # On supprime le caractère "G" en dernière position
        dfree=${dfree%?}

        for vm in `cat $1`
                do
                duse=$2
                # or duse=$(echo $vm | cut -d ";" -f4) -> le quatrieme champs sera le disque auxiliaire
                let dusesum=$dusesum+$duse
        done
        echo "espace libre $dfree "
        echo "epace disque à déployer : $dusesum  "
        if [ "$(($dfree-5))" -le "$dusesum" ]
                then
                echo "Vous n'avez pas assez d'espace disque libre."
        fi
}

make_interfaces () {
				vm.params ${1}
				mkdir -p ${2}/${host}.interfaces/
				echo "
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback
# The primary network interface
auto $ifname
allow-hotplug $ifname
iface eth0 inet static
address $ip
netmask $netmask
network $network
broadcast $bcast
gateway $gw
dns-nameservers $dns
				" > ./${2}/${host}.interfaces/interfaces
				echo "nameserver $dns" >${2}/${host}.interfaces/resolv.conf
			}
