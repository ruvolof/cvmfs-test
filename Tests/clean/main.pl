use strict;
use warnings;
use Sudo;
use ZeroMQ qw/:all/;
use FindBin qw($Bin);

my $socket_path = 'ipc:///tmp/server.ipc';

# This will be the name for the socket
my $name = 'CLEAN';

# In this two variable I'll store the object that runs sudo commands and
# the exit status of the commands
my ($su, $run);

# This functions accept an object returned from sudo->run and will check
# if there were errors running the code.
sub check_status {
	# Retrieving the object
	my $run = shift;
	
	if (exists($run->{error})) {
		print "Failed.\n";
	}
	else {
		print "Done.\n";
	}
}

# This first call erase all RSA related files
$su = Sudo->new(
				{
					sudo => '/usr/bin/sudo',
					username => 'root',
					pogram => '/usr/bin/rm',
					program_args => '-f /tmp/cvmfs_test.key /tmp/cvmfs_test.csr'.
									' /tmp/cvmfs_test.crt /tmp/whitelist.test.*'.
									' /tmp/cvmfs_master.key /tmp/cvmfs_master.pub'
				}
);

print 'Erasing RSA keys... ';
$run = $su->sudo_run();
check_status($run);

# This instance will erase configuration files created in /etc/cvmfs/config.d
$su = Sudo->new(
				{
					sudo => '/usr/bin/sudo',
					username => 'root',
					program => '/usr/bin/rm',
					program_args => '-f /etc/cvmfs/config.d/127.0.0.1.conf'
				}
);

print 'Erasing configuration files in /etc/cvmfs/config.d... ';
$run = $su->sudo_run();
check_status($run);

# This instance will erase /tmp/cvmfs.faulty
$su = Sudo->new(
				{
					sudo => '/usr/bin/sudo',
					username => 'root',
					program => '/usr/bin/rm',
					program_args => '-f /tmp/cvmfs.faulty'
				}
);

print 'Erasing /tmp/cvmfs.faulty... ';
$run = $su->sudo_run();
check_status($run);

# This instance will erase all previous extracted repository
$su = Sudo->new(
				{
					sudo => '/usr/bin/sudo',
					username => 'root',
					program => '/usr/bin/rm',
					program_args => '-fr /tmp/server'
				}
);

print 'Erasing /tmp/server directory... ';
$run = $su->sudo_run();
check_status($run);

# This instance will run 'restarting_services.sh'
$su = Sudo->new(
				{
					sudo => '/usr/bin/sudo',
					username => 'root',
					program => 'sh',
					program_args => "$Bin/restarting_services.sh"
				}
);

print 'Restarting services... ';
$run = $su->sudo_run();
check_status($run);

# Opening the socket to launch 'killall' command
my $ctxt = ZeroMQ::Context->new();
my $socket = $ctxt->socket(ZMQ_PUSH);
$socket->setsockopt(ZMQ_IDENTITY, $name);

$socket->connect($socket_path);

print 'Killing all existing processes... ';
$socket->send('killall');
print "Done.\n";

# Closing the socket, we no longer need it.
$socket->close();
$ctxt->term();

exit 0;
