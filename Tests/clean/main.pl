use strict;
use warnings;
use ZeroMQ qw/:all/;
use FindBin qw($Bin);

my $socket_path = '/tmp/server.ipc';
my $socket_protocol = 'ipc://';

# This will be the name for the socket. This socket isn't supposed to receive any message.
# But the server will still try to send them to it. When the server will realize, that this socket
# isn't listening, the server will discard them.
my $name = 'CLEAN';

# Print statement are self explanatory.

print 'Erasing RSA keys... ';
system("sudo rm -f /tmp/cvmfs_test.key /tmp/cvmfs_test.csr /tmp/cvmfs_test.crt /tmp/whitelist.test.* /tmp/cvmfs_master.key /tmp/cvmfs_master.pub > /dev/null 2>&1");
print "Done.\n";

print 'Erasing configuration files in /etc/cvmfs/config.d... ';
system("sudo rm -f /etc/cvmfs/config.d/127.0.0.1.conf > /dev/null 2>&1");
print "Done.\n";

print 'Erasing /tmp/cvmfs.faulty... ';
system("sudo rm -f /tmp/cvmfs.faulty > /dev/null 2>&1");
print "Done.\n";

print 'Erasing /tmp/server directory... ';
system("sudo rm -f --recursive /tmp/server > /dev/null 2>&1");
print "Done.\n";

print 'Restarting services... ';
system("sudo Tests/Common/restarting_services.sh >> /dev/null 2>&1");
print "Done.\n";

# Opening the socket to launch 'killall' command.
my $ctxt = ZeroMQ::Context->new();
my $socket = $ctxt->socket(ZMQ_DEALER) || die "Couldn't create socket: $!.\n"; 
$socket->setsockopt(ZMQ_IDENTITY, $name);

$socket->connect( "${socket_protocol}${socket_path}" );

print 'Killing all existing processes... ';
$socket->send('killall');
print "Done.\n";

# Closing the socket, we no longer need it.
$socket->close();
$ctxt->term();

exit 0;
