use strict;
use warnings;
use Net::DNS::Nameserver;
use Getopt::Long;
use Socket;
use IO::Handle;

my $port = 5300;
my $fixed = undef;
my $timeout;
my $outputfile = '/var/log/cvmfs-test/named.out';
my $errorfile = '/var/log/cvmfs-test/named.err';

my $ret = GetOptions ("port=i" => \$port,
					  "fixed=s" => \$fixed,
					  "timeout" => \$timeout,
					  "stdout=s" => \$outputfile,
					  "stderr=s" => \$errorfile );

sub reply_handler {
	# If is set the timeout flag, the reply_handler will wait 180s
	if ($timeout){
		sleep 180;
		return;
	}
    my ($qname, $qclass, $qtype, $peerhost,$query,$conn) = @_;
    my ($rcode, @ans, @auth, @add);

    print "Received query from $peerhost to ". $conn->{sockhost}. "\n";
    $query->print;

    if ($qtype eq "A") {
		my $ip;
		# If it is not set the fixed flag, the server will retrieve the correct ip, else...
		if (!defined($fixed)){
			my $packed_ip = gethostbyname($qname);
			$ip = inet_ntoa($packed_ip);
		}
		else {
			# ... it will serve always the selected ip.
			$ip = $fixed;
		}
        my ($ttl, $rdata) = (3600, "$ip");
        my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
        push @ans, $rr;
        $rcode = "NOERROR";
    }
    elsif( $qname eq "foo.example.com" ) {
        $rcode = "NOERROR";
    }
    else{
        $rcode = "NXDOMAIN";
    }

    # mark the answer as authoritive (by setting the 'aa' flag
    return ($rcode, \@ans, \@auth, \@add, { aa => 1 });
}

my $ns = new Net::DNS::Nameserver(
    LocalPort    => $port,
    ReplyHandler => \&reply_handler,
    Verbose      => 1
    ) || die "couldn't create nameserver object\n";

my $pid = fork();

# Command for the forked process
if (defined ($pid) and $pid == 0){
	open (my $errfh, '>', $errorfile ) || die "Couldn't open $errorfile: $!\n";
	STDERR->fdopen( \*$errfh, 'w' ) || die "Couldn't set STDERR to $errorfile: $!\n";

	open (my $outfh, '>', $outputfile ) || die "Couldn't open $outputfile: $!\n";
	STDOUT->fdopen( \*$outfh, 'w' ) || die "Couldn't set STDOUT to $outputfile: $!\n";
	$ns->main_loop;
	
}

# Command for the main script
unless ($pid == 0){
	print "DNS started on port $port with PID $pid.\n";
	print "You can read its output in '$outputfile'.\n";
	print "Errors are stored in '$errorfile'.\n";
}
	
exit 0;
