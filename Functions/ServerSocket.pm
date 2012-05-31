package Functions::ServerSocket;

################################################
# This package will contain the functions to send and receive message
# on the server side
################################################

use strict;
use warnings;
use ZeroMQ qw/:all/;

# Next lines are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(receive_msg send_msg end_msg close_socket term_ctxt);

# Initialising the socket
my $ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context.\n";
my $socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_DEALER) || die "Couldn't create socket.\n";

ZeroMQ::Raw::zmq_bind( $socket, 'ipc:///tmp/server.ipc' );

# Receiving a message
sub receive_msg {
	my $msg = ZeroMQ::Raw::zmq_recv($socket);
	my $line = ZeroMQ::Raw::zmq_msg_data($msg) || die "Couldn't retrieve pointer to data: $!\n";
	
	return $line;
}

# Send a message
sub send_msg {
	# Retrieve message
	my $msg = shift;
	
	ZeroMQ::Raw::zmq_send($socket, $msg);
}

# End message. Use this functions to tell the shell that no more output will arrive.
sub end_msg {
	ZeroMQ::Raw::zmq_send($socket, "END\n");
}

# Close the socket
sub close_socket {
	ZeroMQ::Raw::zmq_close($socket);
}

# Term ZeroMQ context
sub term_ctxt {
	ZeroMQ::Raw::zmq_term($ctxt);
}

1;
