use strict;
use warnings;
use Archive::Tar;
use Archive::Extract;
use ZeroMQ qw/:all/;
use File::Copy;
use Sudo;

use FindBin qw($Bin);

my $tmp_repo = '/tmp/repo/';
my $repo_pub = $tmp_repo . 'pub';
my $outputfile = '/var/log/cvmfs-test/faulty_proxy.out';
my $errorfile = '/var/log/cvmfs-test/faulty_proxy.err';
my $socket_path = 'ipc:///tmp/server.ipc';
my $testname = 'FAULTY_PROXY';

sub get_daemon_output {
	my $socket = shift;
	my ($data, $reply) = '';
	while ($data ne "END\n") {
		$reply = $socket->recv();
		$data = $reply->data;
		print $data if $data ne "END\n";
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
	my $ae = Archive::Extract->new( archive => "$Bin/repo/pub.tar.gz", type => 'tgz' );
	my $ae_ok = $ae->extract( to => $tmp_repo ) or die ae->error;
	print "Done.\n";
	
	print "Opening the socket to communicate with the server... \n";
	my $ctxt = ZeroMQ::Context->new();
	my $socket = $ctxt->socket(ZMQ_DEALER);
	my $setopt = $socket->setsockopt(ZMQ_IDENTITY, $testname);
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
	
	print 'Configuring cvmfs... ';
	my $su = Sudo->new(
                  {
                   sudo         => '/usr/bin/sudo',                              
                   program      => "$Bin/config_cvmfs.sh"
                  }
	);
	my $sudo = su->sudo_run();
	print "Done.\n";
	
	print 'Creating RSA key... ';
	system("$Bin/creating_rsa.sh");
	print "Done.\n";
    
	print 'Signing files... ';
	my @files_to_sign;
	my $select = sub {
	if ($File::Find::name =~ m/\.cvmfspublished/){
			push @files_to_sign,$File::Find::name;
		}
	};
	find( { wanted => $select }, $repo_pub );
	foreach (@files_to_sign) {
		copy($_,"$_.unsigned");
		system("$Bin/cvmfs_sign-linux32 -c /tmp/cvmfs_test.crt -k /tmp/cvmfs_test.key -n 127.0.0.1 $_");		
	}
	copy("tmp/whitelist.test.signed", "$repo_pub/catalogs/.cvmfswhitelist");
	print "Done.\n";
	
	print 'Configurin RSA key... ';
	system("$Bin/configuring_rsa.sh");
	print "Done.\n";
}

if (defined ($pid) and $pid != 0) {
	print "FAULTY_PROXY test started.\n";
	print "You can read its output in $outputfile.\n";
	print "Errors are stored in $errorfile.\n";
}

exit 0;
