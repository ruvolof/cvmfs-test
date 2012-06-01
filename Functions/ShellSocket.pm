package Functions::ShellSocket;

#####################################
# Here will be stored all the functions related to socket on 
# the shell side.
#####################################

use strict;
use warnings;
use ZeroMQ q/:all/;

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(start_shell_socket receive_shell_msg send_shell_msg close_shell_socket term_shell_ctxt);

# Modify this variables to change the path to the socket
my $socket_path = 'ipc:///tmp/server.ipc';

# Variables shared among all functions
my $ctxt;
my $socket;

# Starting the shell socket
sub start_shell_socket {
	$ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context.\n";
	$socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_DEALER) || die "Couldn't create socket.\n";

	my $rc = ZeroMQ::Raw::zmq_connect( $socket, $socket_path );
	
	if ($rc != 0) {
		return 0;
	}
	else {
		return 1;
	}
}

# Receiving a message
sub receive_shell_msg {
	my $msg = ZeroMQ::Raw::zmq_recv($socket);
	my $line = ZeroMQ::Raw::zmq_msg_data($msg) || die "Couldn't retrieve pointer to data: $!\n";
	
	return $line;
}

# Send a message
sub send_shell_msg {
	# Retrieve message
	my $msg = shift;
	
	ZeroMQ::Raw::zmq_send($socket, $msg);
}

# Close the socket
sub close_shell_socket {
	ZeroMQ::Raw::zmq_close($socket);
}

# Term ZeroMQ context
sub term_shell_ctxt {
	ZeroMQ::Raw::zmq_term($ctxt);
}

1;
