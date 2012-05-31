#!/usr/bin/perl

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# Next line adds the script directory to the lib path
use lib $Bin;

use strict;
use warnings;
use Proc::Spawn;
use Functions::Shell qw(check_daemon check_command start_daemon);
use ZeroMQ qw/:all/;

# A simple welcome.
print '#'x80 . "\n";
print "Welcome in the interactive shell of the CernVM-FS testing system.\n";
print "Type 'help' for a list of available commands.\n";
print '#'x80 . "\n";

# If the daemon is not running, the shell will ask the use if run it
unless (check_daemon()) {
	print 'The daemon is not running. Would you like to run it now? [Y/n]';
	my $answer = <STDIN>;
	if($answer eq "\n" or $answer eq "Y\n" or $answer eq "y\n"){
		start_daemon();
	}
}

# Connect to the socket
my $ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context: $!\n.";
my $socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_DEALER) || die "Couldn't create socket: $!\n.";

ZeroMQ::Raw::zmq_connect( $socket, 'ipc:///tmp/server.ipc' );

# Infinite loop for the shell. It will switch between two shells: the first one
# is the one used when the shell is connected to the daemon. The second one is used
# when the daemon is not running and will have less options available.
# Both shell terminates on exit.
while(1){
	# This is the first shell, the one used to communicate with the daemon
	while(check_daemon()){
		print '-> ';
		# Reading an input line.
		my $line = <STDIN>;
		chomp($line);
		
		# Checking if the command refer to the shell and not to the daemon
		my $continue = check_command($line);
		# If the command was already executed, passing to the next while cicle
		next if $continue;
		
		# Send the command through the socket
		ZeroMQ::Raw::zmq_send($socket, $line);
		
		# Get answer from the daemon
		my $reply = '';
		while ($reply ne "END\n") {
			my $msg = ZeroMQ::Raw::zmq_recv($socket);
			$reply = ZeroMQ::Raw::zmq_msg_data($msg);
			print $reply if $reply ne "END\n";
		}
	}
	
	# This is the second shell, use when the daemon is closed
	while(!check_daemon()){
		print '(Daemon not running) -> ';
		# Reading an input line.
		my $line = <STDIN>;
		chomp($line);
		
		# Launching the command
		check_command($line);
	}
}
