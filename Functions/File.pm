package Functions::File;

#######################################
# In this file will be stored all functions to manipulate file
# and directory.
#######################################

use strict;
use warnings;

# This code is needed to export the functions in the main package
use base 'Exporter';
use vars qw/ @EXPORT_OK /;
@EXPORT_OK = qw{ recursive_mkdir };


# This functions accept an absolute path and will recursive
# create the whole path. Is the equivalent of "make_path" in
# newer perl version or 'mkdir -p' in any Linux system.
sub recursive_mkdir {
	my $path = shift;
	unless ($path =~ m/^\/[_0-9a-zA-Z]+$/) {
		my $prevpath = $path;
		$prevpath =~ s/\/(.*)(\/.*)$/\/$1/;
		recursive_mkdir($prevpath);
	}
	if (!-e $path and !-d $path) {
		mkdir($path);
	}
}
