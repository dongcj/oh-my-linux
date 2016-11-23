#!/usr/bin/perl

#Parameter 1 - IP address of the host to check
#Parameter 2 - Destination port to check. If port is 0 then use ping instead of opening tcp socket

use IO::Socket;

my $numArgs = $#ARGV + 1;

if ($numArgs < 1) {
    print "Please provide hostname for the server to check\n";
    exit 10;
}

my $hostName = $ARGV[0];
my $port = $ARGV[1];

if ($port != 0) {
	my $sock = new IO::Socket::INET ( 
			PeerAddr => $hostName, 
			PeerPort => $port, 
			Proto => 'tcp',
			Timeout => 3, ) 
		    or exit(1);

	close($sock);
} else {
	my $p = Net::Ping->new()->ping($hostName)
		or exit(1);
	$p->close();
}

exit(0);
