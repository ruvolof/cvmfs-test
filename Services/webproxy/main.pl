use HTTP::Proxy;
use Getopt::Long;

my $port = 3128;

my $ret = GetOptions ( "port=i" => \$port );

my $proxy = HTTP::Proxy->new;
$proxy->port( $port );

my $pid = fork();

# Command for the forked process
if ( defined($pid) and $pid == 0 ) {
	open (my $outfh, '>', '/tmp/cvmfs-webproxy.out') || die "Couldn't open /tmp/cvmfs-webproxy.out: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to /tmp/cvmfs-webproxy.out: $!\n";
	$proxy->start;
}

# Command for the main script
unless ($pid == 0) {
	print "Proxy HTTP started on port $port with PID $pid.\n";
	print "You can read its output in '/tmp/cvmfs-webproxy.out'.\n";
}

exit 0;
