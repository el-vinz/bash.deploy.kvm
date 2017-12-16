#!/bin/bash

. ./common.sh

check_net () {
                        checkit=$(ipcalc $2/$3 -b | grep 'INVALID')
                        if [ -n "$checkit" ]
                        then
                                echo "Le réseau est invalide"
                                ipcalc $net_ip/$netmask -b
                                return 1
                        fi
                        hosts=$(ipcalc -b $2/$3| grep Hosts | cut -d " " -f2)
                        broadcast=$(ipcalc -b $2/$3 | grep Broadcast | cut -d " " -f2)
                        firstip=$(ipcalc -b $2/$3 | grep HostMin | cut -d " " -f4)
                        lastip=$(ipcalc -b $2/$3 | grep HostMax | cut -d " " -f4)
                        hosts=$(ipcalc -b $2/$3 | grep Hosts | cut -d " " -f2)
                        netmask=$(ipcalc -b $2/$3 | grep Netmask | cut -d " " -f4)

                        if ! check_ping $5
                        then
                                return 1
                        fi
                echo "
#################    Vérifiez la configuration de $1    ###############

                        Nom réseau : $1
                        Réseau : $2
                        Masque : $3
                        Passerelle par défaut : $2 (par défaut la carte virtuelle)
                        dns : $5
                        Ip minimale : $firstip
                        IP maximale : $lastip
                        Nombre d'hôtes : $hosts

##################################################################
                "
confirm_it
}

make_card () {
                macaddr=$(echo 00$(od -txC -An -N5 /dev/random|tr \  :))

                echo "<network>
<name>$2</name>
 <uuid>$(uuidgen)</uuid>
 <forward mode='nat'>
  <nat>
    <port start='1024' end='65535'/>
  </nat>
</forward>
 <bridge name="\'virbr${1}\'" stp='on' delay='0'/>
 <mac address="\'$macaddr\'"/>
 <domain name="\'$2\'"/>
 <ip address="\'$3\'" netmask="\'$4\'">
 </ip>
 </network>" > $2.xml

virsh net-define $2.xml
virsh net-start $2
virsh net-autostart $2

if ! check_ping $3
then
  return 1
fi


}

set_networks () {

      for netsub in $(cat $1)
      do
            card_number=$(echo $netsub | cut -d ";" -f1)
            net_name=$(echo $netsub | cut -d ";" -f2)
            net_ip=$(echo $netsub | cut -d ";" -f3)
            gateway=$net_ip
            netmask=$(echo $netsub | cut -d ";" -f4)
            dns=$(echo $netsub | cut -d ";" -f5)

            #Vérification de la cohérence du réseau.
            check_net $net_name $net_ip $netmask $gateway $dns

            check=$(virsh net-list | grep $net_name | cut -d " " -f2)

            if [ ! -z $check ]
            then
              echo "le réseau $net_name existe déjà "
              read -p "Souhaitez vous le recréer ?" -n1 answer
              case $answer in
                              [yYoO]*) virsh net-undefine $net_name
                              virsh net-destroy $net_name
                              ;;
                              [nN]*) echo "Impossible de créer $net_name Fin de script "
                              exit 1
                              ;;
                              *) "Erreur de saise. Fin"
                              exit 1
                              ;;
              esac

            fi
            make_card $card_number $net_name $net_ip $netmask
      done
}

set_networks $1
