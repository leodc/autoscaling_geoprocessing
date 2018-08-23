#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

my $sleepMainLoop = 1;
my $prometheus = 0;

my %gtm = (
	master => 0,
	proxy => 0,
	slave => 0
);

my @coordinators = ();
my @datanodes = ();

my @coordinatorsName = ();
my @datanodesName = ();

my @removed = ();

my $test_db = "test_db";
my $test_table = "osm_points";


sub main {
	logEntry("Starting monitor...\n");
	while (1) {
		sleep($sleepMainLoop);

		if( !$gtm{master} ){
			lookGTM();
		}else{
			lookGTMProxy();
			lookGTMSlave();
			lookCoordinators();
			lookDatanodes();

			checkPrometheus();
			checkMembersLeft();
		}
	}
}

sub checkMembersLeft {
	my $gtm_search = qx(consul members --status=left);
	my @lines = split /\n/, $gtm_search;

	my $skip = 1;
	for my $record (@lines) {
		if($skip){
			$skip = 0;
			next;
		}

		my ($node, $address, $status, $tags) = ($record =~ /(\S+)\s+(\S+):\d+\s+(\S+)\s+(\S+)/);

		if ( !grep( /^$address$/ , @removed ) ) {
			if ( grep( /^$address$/ , @datanodes ) ) {
				logEntry("Datanode $address left... removing from cluster...\n");

				my $index = 0;
				foreach my $datanode ( @datanodes ){
					if ( $datanode eq $address ){
						my $name = $datanodesName[$index];

						if($prometheus){
							my $coordinator = $coordinators[0];

							logEntry("Updating node list with $name...\n");
							my $response = qx(ssh ubuntu\@$coordinator "psql -p 30001 -d $test_db -U ubuntu -c 'ALTER TABLE $test_table DELETE NODE ($name)';");
							logEntry("$response\n");
						}

						my $response = qx(pgxc_ctl remove datanode master $name clean);

						print("$response\n");
						push( @removed, $address );

						last;
					}
					$index++;
				}
			} elsif ( grep( /^$address$/ , @coordinators ) ) {
				logEntry("Coordinator $address left... removing from cluster\n");

				my $index = 0;
				foreach my $coordinator ( @coordinators ){
					if ( $coordinator eq $address ){
						my $name = $coordinatorsName[$index];
						my $response = qx(pgxc_ctl remove coordinator master $name clean);

						print("$response\n");
						push( @removed, $address );

						last;
					}
					$index++;
				}
			}
		}
	}
}


sub checkPrometheus {
	if( ($prometheus) || (!$gtm{slave}) || (!$gtm{proxy}) || (@coordinators < 2) || (@datanodes < 2) ) {
		return;
	}

	# INSERTING DATA IN COORDINATOR
	logEntry("Basic infrastructure ready\n");
	my $coordinator = $coordinators[0];

	logEntry("Sending data to coordinator $coordinator...");
	my $response = qx(scp /home/ubuntu/osm_points.csv ubuntu\@$coordinator:/home/ubuntu/osm_points.csv);
	logEntry("OK\n");

	logEntry("Sending script to insert data...");
	$response = qx(scp /home/ubuntu/insert_data.sh ubuntu\@$coordinator:/home/ubuntu/insert_data.sh);
	logEntry("OK\n");

	logEntry("Running script to insert data...");
	$response = qx(ssh ubuntu\@$coordinator "/bin/bash /home/ubuntu/insert_data.sh");
	logEntry("OK\n");

	# UPDATING PROMETHEUS SERVICE
	logEntry("Updating prometheus...\n");

	my $gtm_search = qx(consul catalog nodes);

	if ( $gtm_search !~ /no nodes match.*|.*error.*/io ){
		my @lines = split /\n/, $gtm_search;

		logEntry("Writting ips...");
		my $skip = 1;
		open (PROMETHEUS_FILE, '>> /home/ubuntu/prometheus-2.3.2.linux-amd64/prometheus.yml');
		for my $record (@lines) {
			if($skip){
				$skip = 0;
				next;
			}

			my ($node, $id, $address, $dc) = ($record =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
			print PROMETHEUS_FILE "        - $address:9100\n";
		}

		logEntry("OK\n");
	}

	close (PROMETHEUS_FILE);

	logEntry("Triggering prometheus reload\n");
	qx(curl -X POST http://localhost:9090/-/reload);

	$prometheus=1;
}


sub lookGTM {
	my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm);

	if ( $gtm_search !~ /no nodes match.*|error.*/io ){
		my @lines = split /\n/, $gtm_search;

		my $arrSize = @lines;
		if ( $arrSize > 1 ){
			my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

			logEntry("New GTM found... $address\n");

			## add gtm to known_hosts
			system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

			## add instance to the cluster
			system("pgxc_ctl add gtm master gtm $address 20001 $ENV{dataDirRoot}/gtm");

			logEntry("$address added to cluster as GTM\n");

			$gtm{master} = $address;
		} else {
			logEntry("No GTM candadite was found.\n @lines");
		}
	}

	return;
}


sub lookGTMProxy {
	if ( !$gtm{proxy} ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm_proxy);

		if ( $gtm_search !~ /no nodes match.*|error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $arrSize = @lines;
			if ( $arrSize > 1 ){
				my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				logEntry("New GTM PROXY found... $address\n");

				## add gtm to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				## add instance to the cluster
				my $status = system("pgxc_ctl add gtm_proxy gtm_proxy $address 20101 $ENV{dataDirRoot}/gtm_proxy");
				if (($status >>=8) != 0) {
					logEntry("Error running... pgxc_ctl add gtm_proxy master gtm_proxy $address 20101 $ENV{dataDirRoot}/gtm_proxy\n");
				}else{
					logEntry("$address added to cluster as GTM PROXY\n");
					$gtm{proxy} = $address;
				}
			}
		}
	}

	return;
}


sub lookGTMSlave {
	if ( !$gtm{slave} ){
		my $gtm_search = qx(consul catalog nodes -node-meta profile=gtm_slave);

		if ( $gtm_search !~ /no nodes match.*|error.*/io ){
			my @lines = split /\n/, $gtm_search;

			my $arrSize = @lines;
			if ( $arrSize > 1 ){
				my ($node, $id, $address, $dc) = ($lines[1] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

				logEntry("New GTM SLAVE found...\n");

				## add gtm to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				## add instance to the cluster
				logEntry("pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave... ");

				my $status = system("pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave");
				if (($status >>=8) != 0) {
					logEntry("Error calling... pgxc_ctl add gtm slave gtm_slave $address 20002 $ENV{dataDirRoot}/gtm_slave\n");
				}else{
					logEntry("$address added to cluster as GTM SLAVE\n");
					$gtm{slave} = $address;
				}
			}
		}

	}

	return;
}


sub lookCoordinators {
	my $gtm_search = qx(consul catalog nodes -node-meta profile=coordinators);

	if ( $gtm_search !~ /no nodes match.*|.*error.*/io ){
		my @lines = split /\n/, $gtm_search;

		my $skip = 1;
		for my $record (@lines) {
			if($skip){
				$skip = 0;
				next;
			}

			my ($node, $id, $address, $dc) = ($record =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

			if ( !grep( /^$address$/ , @coordinators ) ) {
				logEntry("coordinator -- new coordinator found... $address\n");

				## add the new member to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				my $coordinatorsCount = @coordinators  + 1;

				## add instance to the cluster
				my $port_a = 30001;
				my $port_b = 30001 + $coordinatorsCount;

				my $name = "coord$coordinatorsCount";
				my $response = qx(pgxc_ctl add coordinator master $name $address $port_a $port_b $ENV{dataDirRoot}/coord_master.$coordinatorsCount none none);

				if ( $response !~ /no nodes match.*|.*error.*/io ){
					logEntry("$address added to cluster as coordinator.$coordinatorsCount\n");

					if($prometheus){
						logEntry("Adding to prometheus...");
						open (PROMETHEUS_FILE, '>> /home/ubuntu/prometheus-2.3.2.linux-amd64/prometheus.yml');
						print PROMETHEUS_FILE "        - $address:9100\n";
						close (PROMETHEUS_FILE);
						logEntry("OK\n");

						logEntry("Triggering prometheus reload\n");
						qx(curl -X POST http://localhost:9090/-/reload);
					}

					push( @coordinators, $address );
					push( @coordinatorsName, $name );
				}else{
					logEntry("Error running... pgxc_ctl add coordinator master $name $address $port_a $port_b $ENV{dataDirRoot}/coord_master.$coordinatorsCount none none\n");
				}

			}
		}
	}

	return;
}



sub lookDatanodes {
	my $gtm_search = qx(consul catalog nodes -node-meta profile=datanodes);

	if ( $gtm_search !~ /no nodes match.*|.*error.*/io ){
		my @lines = split /\n/, $gtm_search;

		my $skip = 1;
		for my $record (@lines) {
			if($skip){
				$skip = 0;
				next;
			}

			my ($node, $id, $address, $dc) = ($record =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);

			if ( !grep( /^$address$/ , @datanodes ) ) {
				logEntry("datanodes -- new worker found... $address\n");

				## add the new member to known_hosts
				system("ssh-keyscan -H $address >> /home/ubuntu/.ssh/known_hosts");

				my $datanodesCount = @datanodes  + 1;

				## add instance to the cluster
				my $port_a = 40000 + $datanodesCount;
				my $port_b = 41000 + $datanodesCount;

				my $name = "dn$datanodesCount";
				my $response = qx(pgxc_ctl add datanode master $name $address $port_a $port_b $ENV{dataDirRoot}/dn_master.$datanodesCount none none none);

				if ( $response !~ /no nodes match.*|.*error.*/io ){
					logEntry("$address added to cluster as datanode.$datanodesCount\n");

					if($prometheus){
						my $coordinator = $coordinators[0];

						logEntry("Updating node list with $name...\n");
						my $response = qx(ssh ubuntu\@$coordinator "psql -p 30001 -d $test_db -U ubuntu -c 'ALTER TABLE $test_table ADD NODE ($name)';");
						logEntry("$response\n");


						logEntry("Adding to prometheus...");
						open (PROMETHEUS_FILE, '>> /home/ubuntu/prometheus-2.3.2.linux-amd64/prometheus.yml');
						print PROMETHEUS_FILE "        - $address:9100\n";
						close (PROMETHEUS_FILE);
						logEntry("OK\n");

						logEntry("Triggering prometheus reload\n");
						qx(curl -X POST http://localhost:9090/-/reload);
					}

					push( @datanodes, $address );
					push( @datanodesName, $name );
				}else{
					logEntry("Error adding datanode -- $response");
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

	print("$dateTime ---- $logText");
}

# start script
main();
