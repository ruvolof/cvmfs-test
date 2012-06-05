use strict;
use warnings;
use Archive::Extract;
use ZeroMQ qw/:all/;
use Crypt::OpenSSL::RSA;

use FindBin qw($Bin);

my $tmp_repo = '/tmp/repo/';
my $repo_pub = $tmp_repo . 'pub';
my $outputfile = '/var/log/cvmfs-test/faulty_proxy.out';
my $errorfile = '/var/log/cvmfs-test/faulty_proxy.err';
my $socket_path = 'ipc:///tmp/server.ipc';

sub get_daemon_output {
	my $socket = shift;
	my $reply = '';
	while ($reply ne "END\n") {
		$reply = $socket->recv();
		print $reply if $reply ne "END\n";
	}
}

my $pid = fork();

if (defined ($pid) and $pid == 0) {
	open (my $errfh, '>', $errorfile) || die "Couldn't open $errorfile: $!\n";
	STDERR->fdopen ( \*$errfh, 'w' ) || die "Couldn't set STDERR to $errorfile: $!\n";
	open (my $outfh, '>', $outputfile) || die "Couldn't open $outputfile: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to $outputfile: $!\n";
	
	print "Creating directory $tmp_repo... ";
	mkdir $tmp_repo;
	print "Done.\n";

	print "Extracting the repository... ";
	my $ae = Archive::Extract->new ( archive => 'repo/pub.tar.gz');
	my $ae_ok = $ae->extract ( to => $tmp_repo ) or die ae->error;
	print "Done.\n";
	
	print "Opening the socket to communicate with the server... \n";
	my $ctxt = ZeroMQ::Context->new();
	my $socket = $ctxt->socket(ZMQ_PUSH);
	$socket->connect( $socket_path );
	
	print "Starting services for test... \n";
	$socket->send("httpd --root $repo_pub --port 8080");
	get_daemon_output($socket);
	sleep 2;
	$socket->send("httpd --root $repo_pub --port 8081 --timeout");
	get_daemon_output($socket);
	sleep 2;
	$socket->send("webproxy --port 3128 --deliver-crap --fail all");
	get_daemon_output($socket);
	sleep 2;
	$socket->send("webproxy --port 3129 --backend http://localhost:8080");
	get_daemon_output($socket);
	sleep 2;
	$socket->send("webproxy --port 3130 --backend http://localhost:8081");
	get_daemon_output($socket);
	sleep 2;
	print "All services started.\n";

}

if (defined ($pid) and $pid != 0) {
	print "faulty_proxy test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
}

exit 0;
