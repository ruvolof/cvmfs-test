package Filters::RecordTransfer;

######################################
# This filter is intended to be used for response
######################################

use strict;
use warnings;
use HTTP::Proxy::BodyFilter::simple;
    
our $body = HTTP::Proxy::BodyFilter::simple->new (
	sub {
		my ( $self, $dataref, $message, $protocol, $buffer ) = @_;
		my $record_file = '/tmp/transferred_data';
		
		if (-e $record_file) {
			my $fh;
			open($fh, '<', $record_file);
			my $actual_size = $fh->getline;
			close($fh);
			my $new_size = $actual_size + (length($$dataref));
			open($fh, '>', $record_file);
			print $fh $new_size;
			close($fh);
		}
		else {
			open (my $fh, '>', $record_file);
			print $fh length($$dataref);
			close($fh);
		}
	}
);

1;
