use HTTP::Proxy;

my $proxy = HTTP::Proxy->new;
$proxy->port( 3128 );

$proxy->start;
