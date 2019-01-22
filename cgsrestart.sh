#!/bin/bash

case $1 in
	d157)
		host=prod157
		batch=cgs-batch-destination
		;;
	*)
		host=$1
		batch=cgs-batch-destination
esac

cgsrestart=/home/snicoud/cgsrestart
ssh -q $host $cgsrestart $batch

echo DONE $host $batch

