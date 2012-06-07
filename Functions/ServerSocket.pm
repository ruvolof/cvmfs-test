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
@EXPORT_OK = qw(start_socket receive_msg send_msg end_msg close_socket term_ctxt);

# Modify this variables to change the path to the socket
my $socket_path = '/tmp/server.ipc';
my $socket_protocol = 'ipc://';

# Variables shared among all functions
my $ctxt;
my $socket;
my $sender = undef;

# Starting the daemon socket
sub start_socket {
	$ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context.\n";
	$socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_ROUTER) || die "Couldn't create socket.\n";

	my $rc = ZeroMQ::Raw::zmq_bind( $socket, "${socket_protocol}${socket_path}" );
	system("chmod 777 $socket_path");
	
	if ($rc != 0) {
		return 0;
	}
	else {
		return 1;
	}
}

# Receiving a message
sub receive_msg {
	my $msg = ZeroMQ::Raw::zmq_recv($socket);
	my $line = ZeroMQ::Raw::zmq_msg_data($msg) || die "Couldn't retrieve pointer to data: $!\n";

	my @check = split /[[:blank:]]/, $line;
	if (scalar(@check) == 1 and $check[0] eq uc($check[0])){
		$sender = $line;
		return "Receiving connection from $sender.\n";
	}
	else {
		return $line;
	}
}

# Select the recipient socket
sub select_recipient {
	ZeroMQ::Raw::zmq_send($socket, $sender, ZMQ_SNDMORE);

	# Undefining $sender to avoid multiple use of this function for the same message
	$sender = undef;
}

# Send a message
sub send_msg {
	# Retrieve message
	my $msg = shift;

	# If $sender is not undef, sending the first part of output with socket identity
	if (defined($sender)){
		select_recipient();
	}
	
	ZeroMQ::Raw::zmq_send($socket, $msg, ZMQ_SNDMORE);
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
