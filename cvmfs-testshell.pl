#!/usr/bin/perl

# The next line is here to help me find the directory of the script
# if you have a better method, let me know.
use FindBin qw($Bin);

# Next line adds the script directory to the lib path
use lib $Bin;

use strict;
use warnings;
use Proc::Spawn;
use Functions::Shell qw(check_daemon check_command start_daemon get_daemon_output);
use Functions::ShellSocket qw(start_shell_socket receive_shell_msg send_shell_msg close_shell_socket term_shell_ctxt);

# A simple welcome.
print '#'x80 . "\n";
print "Welcome in the interactive shell of the CernVM-FS testing system.\n";
print "Type 'help' for a list of available commands.\n";
print '#'x80 . "\n";

# If the daemon is not running, the shell will ask the use if run it
if (!check_daemon()) {
	print 'The daemon is not running. Would you like to run it now? [Y/n]';
	my $answer = <STDIN>;
	if($answer eq "\n" or $answer eq "Y\n" or $answer eq "y\n"){
		start_daemon();
	}
}
else {
	# Starting the socket to communicate with the server
	start_shell_socket();
}

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
		send_shell_msg($line);
		
		# Get answer from the daemon
		get_daemon_output();
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
