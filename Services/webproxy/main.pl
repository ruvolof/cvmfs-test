use HTTP::Proxy qw(:log);
use Getopt::Long;

use FindBin qw($Bin);
use lib $Bin;

use Filters;
use HTTP::Proxy::BodyFilter::complete;

my $port = 3128;
my $forbidden = undef;
my $deliver_crap = undef;
my $fail_at;
our $backend = undef;
my $outputfile = '/var/log/cvmfs-test/webproxy.output';
my $errorfile = '/var/log/cvmfs-test/webproxy.error';
my $body = \$Filters::Filter403::body;
my $header = \$Filters::Filter403::header;

my $ret = GetOptions ( "port=i" => \$port,
					   "fail=s" => \$fail_at,
					   "stdout=s" => \$outputfile,
					   "stderr=s" => \$errorfile,
					   "403" => \$forbidden,
					   "deliver-crap" => \$deliver_crap,
					   "backend=s" => \$backend );
					   
my @fail_at = split(/,/, $fail_at);

if (defined ($forbidden)) {
	$body = \$Filters::Filter403::body;
	$header = \$Filters::Filter403::header;
}

if (defined ($deliver_crap)) {
	$body = \$Filters::FilterCrap::body;
	$header = \$Filters::FilterCrap::header;
}

# Opening file for log
open (LOG, '>>', $outputfile);

my $proxy = HTTP::Proxy->new;
$proxy->port( $port );
$proxy->logfh( *LOG );
$proxy->logmask( ALL );

if ($fail_at[0] ne 'all') {
	foreach my $url (@fail_at) {
		$proxy->push_filter(
			host => $url,
			response => HTTP::Proxy::BodyFilter::complete->new,
			response => $$body,
			response => $$header
		);
	}
}
else {
	$proxy->push_filter (
		response => HTTP::Proxy::BodyFilter::complete->new(),
		response => $$body,
		response => $$header
	);
}

if (defined ($backend)) {
	$proxy->push_filter (
		request => $Filters::ForceBackend::header
	);
}

my $pid = fork();

# Command for the forked process
if ( defined($pid) and $pid == 0 ) {
	open (my $errfh, '>', $errorfile);
	STDERR->fdopen( \*$errfh, 'w' ) || die "Couldn't set STDERR to $errorfile: $!\n";
	$proxy->start;
}

# Command for the main script
unless ($pid == 0) {
	print "Proxy HTTP started on port $port with PID $pid.\n";
	print "You can read its output in $outputfile.\n";
}

exit 0;
