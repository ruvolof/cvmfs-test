package Tests::Common;

##############################
# Common function to set tests environment
##############################

use strict;
use warnings;

use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(get_daemon_output killing_services check_repo);

# This functions will wait for output from the daemon
sub get_daemon_output {
	# It needs to know the socket object to use. It must be a ZeroMQ instance.
	my $socket = shift;
	# The array to store services pids will be passed as second argument
	my @pids = @_;
	
	my ($data, $reply) = '';
	# It will stop waiting for output when it receives the string "END\n"
	while ($data ne "END\n") {
		$reply = $socket->recv();
		$data = $reply->data;
		# Daemon will send data about PIDs od service started for this test.
		# This message will be formatted like 'SAVE_PID:PID', where PID is the part
		# that we have to save.
		if ($data =~ m/SAVE_PID/) {
		    my $pid = (split /:/, $data)[-1];
		    push @pids,$pid;
		}
		print $data if $data ne "END\n" and $data !~ m/SAVE_PID/;
	}
	
	# Returning the new pids array.
	return @pids;
}

# This function will kill all services started, so it can start new processes on the same ports
sub killing_services {
	# Retrieving socket handler
	my $socket = shift;
	# Pass the pids array as second argument
	my @pids = @_;
	
	print "Killing services...\n";
	
	# This chomp is necessary since the server would send the message with a carriage
	# return at the end. But we have to erase it if we want the daemon to correctly
	# recognize the command.
	foreach (@pids) {
		chomp($_);
	}
	
	# Joining PIDs in an unique string
	my $pid_list = join (' ', @pids);
	
	# Removing all elements fro @pids. This command will be called more than once during
	# the test. So we have to empty the arrays if don't want that sequent calling will try
	# to kill already killed services.
	undef @pids;
	
	# Sending the command.
	$socket->send("kill $pid_list");
	get_daemon_output($socket);
	print "Done.\n";
	
	# Returning empty pids array
	return @pids;
}

# This function will check if the repository is accessible, it will return 1 on success and 0 on failure.
# Remember that for two of our tests, success is failure and failure is success.
sub check_repo {
	# Retrieving the folder to check
	my $repo = shift;
	
	my ($opened, $readdir, $readfile) = (undef, undef, undef);
	print "Trying to open and listing the directory...\n";
	
	# Opening the directory.
	$opened = opendir (my $dirfh, $repo);
	
	# Returning false if the directory was not open correctly
	unless ($opened){
	    print "Failed to open directory $repo: $!.\n";
	    return 0;
	}
	
	# Reading the list of files.
	my @files = readdir $dirfh;
	
	# Returning false if the directory can't be read correctly.
	unless (@files) {
	    print "Failed to list directories $repo: $!.\n";
	    return 0;
	}
	else {
		$readdir = 1;
	}
	
	# Printing all files in the directory.
	#print "Directory Listing:\n");
	foreach (@files) {
		print $_ . "\n";
	}
	
	# Opening a file.
	$readfile = open(my $filefh, "$repo/$files[2]");
	
	# Returning false if the file can't be correctly read.
	unless ($readfile) {
		print "Failed to open file $files[2]: $!.\n";
		return 0;
	}
	
	print "File $files[2] content:\n";
	while (defined(my $line = $filefh->getline)) {
		print $line;
	}
	closedir($dirfh);
	
	# Returning true if all operation were done correctly.
	if ($readfile and $readdir and $opened) {
		print "Done.\n";
		return 1;
	}
	else {
		print "Done.\n";
		return 0;
	}
}

1;