#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

my $sleepMainLoop = 1;

my $gtm="";
my $gtmProxy="";
my $gtmSlave="";

my $gtmFlag=0;
my $gtmProxyFlag=0;
my $gtmSlaveFlag=0;

my $gtmCoordinatorsCount = 0;
my @coordinators=();

my $gtmDatanodesCount = 0;
my @datanodes=();



print("Starting monitor...\n");
while (1) {
	sleep($sleepMainLoop);

	lookGTM();
	lookGTMProxy();
	lookGTMSlave();
	lookCoordinators();
	lookDatanodes();
}

#### functions
sub lookGTM {

	if( $gtmFlag == 0 ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm);

		if ( $gtm_search !~ /no nodes match.*|error.*/io ){
		  my @lines = split /\n/, $gtm_search;

		  my $arrSize = @lines;
		  if ( $arrSize > 1 ){
		    my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				print("New GTM found... $address\n");

				## add gtm to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				## add instance to the cluster
				system("pgxc_ctl add gtm master gtm $address 20001 $ENV{dataDirRoot}/gtm");

				print("$address added to cluster as GTM\n");

				$gtm = $address;
				$gtmFlag = 1;
		  } else {
				print("No GTM candadite was found.\n @lines");
			}
		}
	}

	return;
}


sub lookGTMProxy {
	if ( ($gtmProxyFlag == 0) && ($gtmFlag != 0) ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm_proxy);

		if ( $gtm_search !~ /no nodes match.*|error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $arrSize = @lines;
			if ( $arrSize > 1 ){
				my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				print("New GTM PROXY found... $address\n");

				## add gtm to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				## add instance to the cluster
				my $status = system("pgxc_ctl add gtm_proxy gtm_proxy $address 20101 $ENV{dataDirRoot}/gtm_proxy");
				if (($status >>=8) != 0) {
					print("Error running... pgxc_ctl add gtm_proxy master gtm_proxy $address 20101 $ENV{dataDirRoot}/gtm_proxy\n");
				}else{
					print("$address added to cluster as GTM PROXY\n");
					$gtmProxyFlag = 1;
					$gtmProxy = $address;
				}

			}
		}

	}

	return;
}


sub lookGTMSlave {

	if (  ($gtmSlaveFlag == 0) && ($gtmFlag != 0) ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm_slave);

		if ( $gtm_search !~ /no nodes match.*|error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $arrSize = @lines;
			if ( $arrSize > 1 ){
				my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				print("New GTM SLAVE found...\n");
				$gtmSlave = $address;

				## add gtm to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				## add instance to the cluster
				print("pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave... ");

				my $status = system("pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave");
				if (($status >>=8) != 0) {
					print("Error calling... pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave\n");
				}else{
					print("$gtmSlave added to cluster as GTM SLAVE\n");
					$gtmSlaveFlag = 1;
				}
			}
		}

	}


	return;
}


sub lookCoordinators {
	if( $gtmFlag != 0 ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=coordinators);

		if ( $gtm_search !~ /no nodes match.*|.*error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $skip = 1;
			for my $record (@lines) {
				if($skip == 1){
					$skip = 0;
					next;
				}


				my ($node, $id, $address, $dc) = ($record =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				if ( !grep( /^$address$/ , @coordinators ) ) {
					print("coordinator -- new coordinator found... $address\n");

					## add the new member to known_hosts
					system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

					my $coordinatorsCount = $gtmCoordinatorsCount  + 1;

					## add instance to the cluster
					my $port_a = 30000 + $coordinatorsCount;
					my $port_b = 30010 + $coordinatorsCount;

					my $response = qx(pgxc_ctl add coordinator master coord$coordinatorsCount $address $port_a $port_b $ENV{dataDirRoot}/coord_master.$coordinatorsCount none none);
					if ( $response !~ /no nodes match.*|.*error.*/io ){
						print("$address added to cluster as coordinator.$coordinatorsCount\n");
						push( @coordinators, $address );
						$gtmCoordinatorsCount++;
					}else{
					 	print("Error running... pgxc_ctl add coordinator master coord$coordinatorsCount $address $port_a $port_b $ENV{dataDirRoot}/coord_master.$coordinatorsCount none none\n");
					}

				}
			}
		}

	}

	return;
}



sub lookDatanodes {
	if( $gtmFlag != 0 ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=datanodes);

		if ( $gtm_search !~ /no nodes match.*|.*error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $skip = 1;
			for my $record (@lines) {
				if($skip == 1){
					$skip = 0;
					next;
				}


				my ($node, $id, $address, $dc) = ($record =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				if ( !grep( /^$address$/ , @datanodes ) ) {
					print("datanodes -- new worker found... $address\n");

					## add the new member to known_hosts
					system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

					my $datanodesCount = $gtmDatanodesCount  + 1;

					## add instance to the cluster
					my $port_a = 40000 + $datanodesCount;
					my $port_b = 40010 + $datanodesCount;

					# my $response = qx(pgxc_ctl add coordinator master coord$datanodesCount $address $port_a $port_b $ENV{dataDirRoot}/coord_master.$datanodesCount none none);

					my $response = qx(pgxc_ctl add datanode master dn$datanodesCount $address $port_a $port_b $ENV{dataDirRoot}/dn_master.$datanodesCount none none none);
					if ( $response !~ /no nodes match.*|.*error.*/io ){
						print("$address added to cluster as worker.$datanodesCount\n");
						push( @datanodes, $address );
						$gtmDatanodesCount++;
					}else{
					 	print("Error running... pgxc_ctl add datanode master dn$datanodesCount $address $port_a $port_b $ENV{dataDirRoot}/dn_master.$datanodesCount none none none\n");
					}

				}
			}
		}

	}

	return;
}

sub logEntry {
	my ( $logText ) = @_;

	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
	my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;

	print("$dateTime $logText\n");
}