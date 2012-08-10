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
@EXPORT_OK = qw(start_shell_socket receive_shell_msg send_shell_msg close_shell_socket term_shell_ctxt open_testout_socket receive_test_msg close_testsocket close_testctxt);

# Modify this variables to change the path to the socket
my $socket_path = '127.0.0.1:6650';
my $socket_protocol = 'tcp://';

my $testout_protocol = 'tcp://';
my $testout_path = '*:6651';

# Variables shared among all functions
my $ctxt = undef;
my $socket = undef;

my $test_ctxt = undef;
my $test_socket = undef;

# Starting the shell socket
sub start_shell_socket {
	$ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context.\n";
	$socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_DEALER) || die "Couldn't create socket.\n";
	my $setopt = ZeroMQ::Raw::zmq_setsockopt($socket, ZMQ_IDENTITY, 'SHELL');

	my $rc = ZeroMQ::Raw::zmq_connect( $socket, "${socket_protocol}${socket_path}" );
	
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
	if (defined($socket)) {
		ZeroMQ::Raw::zmq_close($socket);
		$socket = undef;
	}
}

# Term ZeroMQ context
sub term_shell_ctxt {
	if (defined($ctxt)) {
		ZeroMQ::Raw::zmq_term($ctxt);
		$ctxt = undef;
	}
}

# Next function are intended to receive test output through a socket
sub open_testout_socket {
	$test_ctxt = ZeroMQ::Raw::zmq_init(5) || die "Couldn't initialise ZeroMQ context.\n";
	$test_socket = ZeroMQ::Raw::zmq_socket($ctxt, ZMQ_PULL) || die "Couldn't create socket.\n";

	my $rc = ZeroMQ::Raw::zmq_bind( $test_socket, "${testout_protocol}${testout_path}" );
	
	if ($rc != 0) {
		return 0;
	}
	else {
		return 1;
	}
}

sub receive_test_msg {
	my $msg = ZeroMQ::Raw::zmq_recv($test_socket);
	my $line = ZeroMQ::Raw::zmq_msg_data($msg) || die "Couldn't retrieve pointer to data: $!\n";
	
	return $line;
}

# Close the socket
sub close_testsocket {
	if (defined($test_socket)) {
		ZeroMQ::Raw::zmq_close($test_socket);
		$test_socket = undef;
	}
}

# Term ZeroMQ context
sub term_testctxt {
	if (defined($test_ctxt)) {
		ZeroMQ::Raw::zmq_term($test_ctxt);
		$test_ctxt = undef;
	}
}

1;
