package Functions::FIFOHandle;

#########################################
# Here will be stored all FIFO related functions
#########################################

use strict;
use warnings;
use IO::Handle;

# Next line are needed to export subroutines to the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw(open_rfifo open_wfifo close_fifo print_to_fifo);

# This function will open the FIFO for reading and will return his handler
sub open_rfifo {
	# Retrieving argument: file path
	my $fifo = shift;
	
	# Checking whether the FIFO is already opened or his position occupied
	unless ( -p $fifo ) {
		unlink $fifo;
		mkfifo($fifo, 0666)
		|| die "Couldn't create $fifo: $!\n";
	}
	
	# Opening the FIFO
	open (my $fh, '<', $fifo) || die "Couldn't open $fifo: $!\n";
	
	return $fh;
}

# This function will open the FIFO for writing and will return his handler
sub open_wfifo {
	# Retrieving argument: file path
	my $fifo = shift;
	
	# Checking whether the FIFO is already opened or his position occupied
	unless ( -p $fifo ) {
		unlink $fifo;
		mkfifo($fifo, 0666)
		|| die "Couldn't create $fifo: $!\n";
	}
	
	# Opening the FIFO
	open (my $fh, '>', $fifo) || die "Couldn't open $fifo: $!\n";
	
	return $fh;
}

# This function will close the given FIFO, actually it's just a rename for
# the close function to remind that we are working with FIFO
sub close_fifo {
	# Retrieving argument: file handler
	my $fh = shift;
	
	close $fh;
}

# This function will open the FIFO, print on it or die if something goes wrong
sub print_to_fifo {
	# Retrieving arguments: the FIFO path, the line to print
	my $fifo = shift;
	my $line = shift;
	
	# Opening the FIFO
	my $fh = open_wfifo($fifo) || die "Couldn't open $fifo: $!\n";
	# Printing to FIFO
	print $fh $line;
	# Closing the FIFO
	close_fifo($fh);
}

1;
