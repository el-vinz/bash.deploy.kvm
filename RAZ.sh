#!/bin/bash

for i in {1..6}; do virsh shutdown 0SERVEUR${i}; done
for i in {1..6}; do virsh undefine 0SERVEUR${i}; done

for net in RED GREEN
do
	virsh net-destroy $net
	virsh net-undefine $net 

done


rm -r *.xml


rm -r *.go

rm -r Virtuals.machines

rm -r xml.store





