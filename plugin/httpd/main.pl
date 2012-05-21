use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin";
use HTTP::AppServer;
use Getopt::Long;

my $not_found;
my $port = 8080;
my $docroot = '/tmp';
my $retriever = 'FileRetriever';

my $ret = GetOptions ( "404" => \$not_found,
					   "port=i" => \$port,
					   "root=s" => \$docroot );

if (defined ($not_found)){
	$retriever = 'Retriever404';
}

# Create server instance at localhost:$port
my $server = HTTP::AppServer->new( StartBackground => 0, ServerPort => $port );
 
# Alias URL
$server->handle('^\/$', '/index.html');

# Loading requested plugin
$server->plugin("$retriever", DocRoot => "$docroot");

# Loading plugin for error handling
$server->plugin('CustomError');

my $pid = fork;

# Command for the forked process
if (defined ($pid) and $pid == 0){
	open (my $outfh, '>', '/tmp/cvmfs-httpd.out') || die "Couldn't open /tmp/cvmfs-httpd.out: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to /tmp/cvmfs-httpd.out: $!\n";
	# Starting server in the forked process
	$server->start;
}

# Command for the main script
unless ($pid == 0) {
	print "HTTPd started on port $port with PID $pid.\n";
	print "You can read its output in '/tmp/cvmfs-httpd.out'.\n";
}

exit 0;
