package Filters::FilterCrap;

######################################
# This filter is intended to be used for response
######################################

use strict;
use warnings;
use HTTP::Proxy::HeaderFilter::simple;
use HTTP::Proxy::BodyFilter::simple;
use IO::File;

our $header = HTTP::Proxy::HeaderFilter::simple->new (
	sub {
		$_[2]->code( 700 );
		$_[2]->message ( 'Crap' );
		$_[1]->header ( Content_Type => 'text/plain; charset=iso-8859-1');
    }
);
    
our $body = HTTP::Proxy::BodyFilter::simple->new (
	sub {
		my ( $self, $dataref, $message, $protocol, $buffer ) = @_;
		unless (defined ($buffer)){
			my $crap = IO::File->new('< /tmp/cvmfs.faulty');

			$$dataref = join '', <$crap>;
		}
	}
);

1;
