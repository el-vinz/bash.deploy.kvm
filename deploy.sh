#!/bin/bash
  #  ./kvm2.0.sh  <liste des vm> <liste des réseaux>
        # les fichiers d'import doivent être de la forme :
        # <hostname>;<ip>;<ram>;<réseau virtuel GREEN, RED..> pour <liste des vm>

        #./go_network <liste des réseaux > de la forme :
                #<N° de carte virtuelle>;<nom du réseau>;<ip de la carte virtuelle>;<masque>;<dns>;<dhcp yes/no>
                #20;RED;192.168.5.1;255.255.255.0;8.8.8.8


  #Pour exécuter le déploiement, il faut s'assurer que l'utilisateur est root dans un premier temps : check_root
  # et que les paquets sont bien installés en amont : check_ipcalc (par exemple)


  #Ensuite on s'occupera du réseau en :
      # analysant les sous réseaux à déployer - présence de dhcp ou non ?
      # en testant les machines à déployer si celles-ci sont bien adressées
. ./common.sh

. ./virt-commons.sh

check_root

./check_ipcalc.sh &>/dev/null


check_csv_net () {

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

if ! check_csv_net $1 $2
  then
  	echo "fin du déploiement. Vérifiez vos fichiers d'import"
  	exit 1
  else
  	echo "Pas de doublon dans $1 et les machines appartiennent toutes à un réseau de $2"
fi

make1file () {
	for net in `cat $1`
	do
	  virt_num=$(echo $net | cut -d ";" -f1)
	  netname=$(echo $net | cut -d ";" -f2)
	  netip=$(echo $net | cut -d ";" -f3)
	  mask=$(echo $net | cut -d ";" -f4)
	  dns=$(echo $net | cut -d ";" -f5)
	  bcast=$(ipcalc $netip/$mask | grep Broadcast | cut -d " " -f2)

	  echo "${virt_num};${netname};${netip};${mask};${dns};${bcast}" >./netlist/${netname}
	  cat ./netlist/${netname} >>netlist.go
		add_end=";${netip};${mask};${dns};${bcast}"
		grep $netname $2 >./tmplist/${netname}
		sed -i "s/$/${add_end}/" ./tmplist/${netname}
		cat ./tmplist/${netname} >>vmlist.go

	done
}

>netlist.go
>vmlist.go

[ ! -d netlist ] && mkdir netlist
[ ! -d tmplist ] && mkdir tmplist

make1file $2 $1

rm -r ./tmplist/
rm -r ./netlist/

#A partir de maintenant, les fichiers d'import à utiliser sont vmlist.go et netlist.go

vm.params () {
  		host=$(echo $1 | cut -d ";" -f1)
  		ip=$(echo $1 | cut -d ";" -f2)
      ram=$(echo $1 | cut -d ";" -f3)
  		netname=$(echo $1 | cut -d ";" -f4)
  		network=$(echo $1 | cut -d ";" -f5)
  		gw=$network
  		netmask=$(echo $1 | cut -d ";" -f6)
  		dns=$(echo $1 | cut -d ";" -f7)
  		bcast=$(echo $1 | cut -d ";" -f8)
}

for vm in `cat vmlist.go`
	do
		vm.params $vm
		if ! verif_ip $ip $netmask $network $netname $host
		then
			echo "Revoyez votre plan IP"
			exit 1
		fi

done

echo "Le plan d'adressage IP a l'air cohérent"

figlet go_network

./go_networks.sh netlist.go

set_template

echo "Vous avez choisi de cloner $template"

show_config $template

[ -d Virtuals.machines ] && rm -r Virtuals.machines

if [ -d xml.store ]
then
  rm -r xml.store && mkdir -p  xml.store/${template}
else
  mkdir -p  xml.store/${template}
fi

virsh dumpxml ${template} >xml.store/${template}/${template}.xml

for vm in `cat vmlist.go`
do
  vm.params $vm
  mkdir xml.store/${host}/
  cp xml.store/${template}/${template}.xml xml.store/${host}/${host}.xml
  sed -i "s/<source network='\(.*\)'/<source network='${netname}'/" xml.store/${host}/${host}.xml
done

check_fullram $1

drives_dir="Virtuals.machines"

[ ! -d "$drives_dir" ] && mkdir $drives_dir

# Ne pas échapper les processus --> Asynchronous job
for vm in `cat vmlist.go`
do
  vm.params $vm
  clone_it $template $host $drives_dir $netname
done

xml.custom () {

  sed -i "s/<source network='\(.*\)'/<source network='${2}'/" $1

}


for vm in `cat vmlist.go`
do
  vm.params $vm

  virsh dumpxml ${host} > ${drives_dir}/${host}.xml

  newxml="${drives_dir}/${host}.xml"

  xml.custom $newxml $netname

done


for vm in `cat vmlist.go`
do
make_interfaces $vm ${drives_dir} $ifname
done


for vm in `cat vmlist.go`
do
	vm.params $vm
	virsh define ${drives_dir}/${host}.xml
  if [ -d /root/mnt/${host} ]
  then
    rm -r /root/mnt/${host}
  else
    mkdir /root/mnt/${host}
  fi

done
configure_vm () {
        vm.params ${1}
                        virt-customize -d $host \
                        --hostname $host \
                        --network \
                        --copy-in ${2}/${host}.interfaces/interfaces:/etc/network/ \
                        --copy-in ${2}/${host}.interfaces/resolv.conf:/etc/
}
for vm in `cat vmlist.go`
do
configure_vm $vm ${drives_dir} &
done

wait

for vm in `cat vmlist.go`
do
  vm.params $vm
  virsh start ${host} &
done

wait

rm *.go

figlet FIN
