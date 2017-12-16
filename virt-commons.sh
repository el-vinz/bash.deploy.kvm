#!/bin/bash

virt_customize () {
                        virt-customize -d $1 \
                        --hostname $1 \
                        --network \
                        --ssh-inject master
}


sysprep () {
                virt-sysprep -d $host \
                --hostname $host \
                --network \
                --copy-in $host/interfaces:/etc/network/ \
                --run-command mkdir /home/master/.ssh \
                --copy-in ssh/id_rsa.pub:/home/master/.ssh/ \
                --run sysprep.sh
}

set_mem () {
        echo "Attribution de ${2}G à $1"
        virsh setmem $host ${ram}G --config
}

at_boot () {
	for vm in `cat $vmlist`; do
        host=$(echo $vm | cut -d ";" -f1)
        mkdir /root/mnt/${host}
        read -e -p "Veuillez selectionner le script à exécuter au premier boot de $host " at_boot

        guestmount -d ${host} -i /root/mnt/${host}
        wait
        cp ./$host/interfaces /root/mnt/${host}/etc/network/interfaces
        if [ -n "$at_boot" ]
                then
                        at_boot=$(basename $at_boot)
                        cp $at_boot /root/mnt/${host}/etc/init.d/
                        chroot /root/mnt/${host}/ /bin/bash -c "chmod +x /etc/init.d/at_boot.sh && update-rc.d at_boot.sh defaults"
                fi
        guestunmount /root/mnt/${host}
        done
}

check_fullram () {
figlet Check_Fullram
        ram=0
        ramsum=0
        for vm in `cat $1`
                do
                ram=$(echo $vm | cut -d ";" -f3)
                let ramsum=$ramsum+$ram
        done

        echo "La totalité de la RAM à déployer est de ${ramsum}G"

        ramsys=$(free -g | grep Mem | awk '{ print $2 }')
        #on garde 2 G de libre pour que le systeme puisse respirer un peu.
        let ramsys=$ramsys-2
        echo "La RAM disponible sur ce système est de  ${ramsys}G"

        if [ $ramsum -le $ramsys ]
                then
                echo "La RAM système permet le déploiement les machines demandées"
                else
                read -p "La RAM système ne permet pas le déploiement les machines demandées

                Souhaitez vous modifier le fichier d'import ? (Y/N)" answer
                case $answer in
                                [yYoO]*) vim $1
                                $0
                                ;;
                                [nN]*) echo "Vous demandez l'impossible - Fin de script"
                                exit 1
                                ;;
                                *) echo "Saisie incorrecte"
                                $0
                                ;;
                esac
        fi

}

set_template () {
        clear
        virsh list --all
        read -e -p "Quelle est la machine à cloner (par défaut $template_def) ?  " template
        if [ -z $template ]
        then
            echo "Vous ne pouvez pas entrer de valeur vide"
            set_template
        fi


        checkvm=$(virsh list --all | grep "$template")
        if [ -z "$checkvm" ]
                then
                        echo "Cette machine n'existe pas"
                        set_template
        fi

        checkrunning=$(virsh domstate $template)
        echo "$template est $checkrunning "

        if [ "$checkrunning" == "en cours d'exécution" ]
                then
                read -p  "Cette machine est en cours de fonctionnement et ne peut être clonée en l'état. Eteindre $template ? (Y/N)" -n 1 answer

                case $answer in

                        [yYoO]*)
                        virsh shutdown $template
                        sleep 5
                        set_template
                        ;;
                        [nN]*) echo "$template ne pourra être clonée - Fin du script"
                        exit 1
                        ;;
                        *) echo "Réponse non valide"
                        set_template
                        ;;
                        esac
        fi
}

show_config () {
  ram_template=$(virsh dumpxml $1 | grep "memory unit" | sed 's/<[^>]*>//g')
  qcow2_template=$(virsh dumpxml $1 | grep "source file" | cut -d "'" -f2)
  echo "La RAM de $1 est de $ram_template"
  echo "L'image disque rattachée de $1 est $qcow2_template"
  [ ! -d /root/mnt/${host} ] && mkdir -p /root/mnt/${host}

  if [ ! -z "$(ls /root/mnt/${host})" ]
  then
    echo "Le dossier n'est pas vide - fin de script"
    exit 1
    #guestunmount /root/mnt/${host}
  fi
  guestmount -d ${1} -i /root/mnt/${host}

    echo "cat /etc/network/interfaces/"

    cat /root/mnt/${host}/etc/network/interfaces

    iface=$(cat /root/mnt/${host}/etc/network/interfaces | grep iface | grep -v loopback)
    ifname=$(echo $iface | cut -d " " -f2)
    ipmode=$(echo $iface | cut -d " " -f4)

    sizedisk=$(du -skh $qcow2_template | cut -f1)
# pour le moment on considérera que la vm à cloner fait 5 Go, et ce sera la même chose pour leur clones.
    echo "
    L'interface réseau est : $ifname

    Le mode de fonctionnement est : $ipmode

    La taille du disque à cloner est : $sizedisk

    "
    confirm_it

  guestunmount /root/mnt/${host}

}

clone_it () {
        macaddr=$(echo 00:60:2d$(od -txC -An -N3 /dev/random|tr \  :))
        echo "clonage de ${1} dans le réseau ${4}"
                virt-clone \
                        --original ${1} \
                        --name $2 \
                        --file ${3}/${2}.qcow2 \
                        --mac $macaddr
}
