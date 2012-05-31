package ZeroMQ;
use strict;
BEGIN {
    our $VERSION = '0.21';
    our @ISA = qw(Exporter);
}
use ZeroMQ::Raw ();
use ZeroMQ::Context;
use ZeroMQ::Socket;
use ZeroMQ::Message;
use ZeroMQ::Poller;
use ZeroMQ::Constants;
use 5.008;
use Carp ();
use IO::Handle;

our %SERIALIZERS;
our %DESERIALIZERS;
sub register_read_type { $DESERIALIZERS{$_[0]} = $_[1] }
sub register_write_type { $SERIALIZERS{$_[0]} = $_[1] }

sub import {
    my $class = shift;
    if (@_) {
        ZeroMQ::Constants->export_to_level( 1, $class, @_ );
    }
}

sub _get_serializer { $SERIALIZERS{$_[1]} }
sub _get_deserializer { $DESERIALIZERS{$_[1]} }

eval {
    require JSON;
    JSON->import(2.00);
    register_read_type(json => \&JSON::decode_json);
    register_write_type(json => \&JSON::encode_json);
};

1;
__END__

=head1 NAME

ZeroMQ - A ZeroMQ2 wrapper for Perl

=head1 SYNOPSIS ( HIGH-LEVEL API )

    # echo server
    use ZeroMQ qw/:all/;

    my $cxt = ZeroMQ::Context->new;
    my $sock = $cxt->socket(ZMQ_REP);
    $sock->bind($addr);
  
    my $msg;
    foreach (1..$roundtrip_count) {
        $msg = $sock->recv();
        $sock->send($msg);
    }

    # json (if JSON.pm is available)
    $sock->send_as( json => { foo => "bar" } );
    my $thing = $sock->recv_as( "json" );

    # custom serialization
    ZeroMQ::register_read_type(myformat => sub { ... });
    ZeroMQ::register_write_type(myformat => sub { .. });

    $sock->send_as( myformat => $data ); # serialize using above callback
    my $thing = $sock->recv_as( "myformat" );

=head1 SYNOPSIS ( LOW-LEVEL API )

    use ZeroMQ::Raw;

    my $ctxt = zmq_init($threads);
    my $rv   = zmq_term($ctxt);

    my $msg  = zmq_msg_init();
    my $msg  = zmq_msg_init_size( $size );
    my $msg  = zmq_msg_init_data( $data );
    my $rv   = zmq_msg_close( $msg );
    my $rv   = zmq_msg_move( $dest, $src );
    my $rv   = zmq_msg_copy( $dest, $src );
    my $data = zmq_msg_data( $msg );
    my $size = zmq_msg_size( $msg);

    my $sock = zmq_socket( $ctxt, $type );
    my $rv   = zmq_close( $sock );
    my $rv   = zmq_setsockopt( $socket, $option, $value );
    my $val  = zmq_getsockopt( $socket, $option );
    my $rv   = zmq_bind( $sock, $addr );
    my $rv   = zmq_send( $sock, $msg, $flags );
    my $msg  = zmq_recv( $sock, $flags );

=head1 INSTALLATION

If you have libzmq registered with pkg-config:

    perl Makefile.PL
    make 
    make test
    make install

If you don't have pkg-config, and libzmq is installed under /usr/local/libzmq:

    ZMQ_HOME=/usr/local/libzmq \
        perl Makefile.PL
    make
    make test
    make install

If you want to customize include directories and such:

    ZMQ_INCLUDES=/path/to/libzmq/include \
    ZMQ_LIBS=/path/to/libzmq/lib \
    ZMQ_H=/path/to/libzmq/include/zmq.h \
        perl Makefile.PL
    make
    make test
    make install

If you want to compile with debugging on:

    perl Makefile.PL -g

=head1 DESCRIPTION

The C<ZeroMQ> module is a wrapper of the 0MQ message passing library for Perl. 
It's a thin wrapper around the C API. Please read L<http://zeromq.org> for
more details on ZeroMQ.

=head1 CLASS WALKTHROUGH

=over 4

=item ZeroMQ::Raw

Use L<ZeroMQ::Raw> to get access to the C API such as C<zmq_init>, C<zmq_socket>, et al. Functions provided in this low level API should follow the C API exactly.

=item ZeroMQ::Constants

L<ZeroMQ::Constants> contains all of the constants that are known to be extractable from zmq.h. Do note that sometimes the list changes due to additions/deprecations in the underlying zeromq2 library. We try to do our best to make things available (at least to warn you that some symbols are deprecated), but it may not always be possible.

=item ZeroMQ::Context

=item ZeroMQ::Socket

=item ZeroMQ::Message

L<ZeroMQ::Context>, L<ZeroMQ::Socket>, L<ZeroMQ::Message> contain the high-level, more perl-ish interface to the zeromq functionalities.

=item ZeroMQ

Loading C<ZeroMQ> will make the L<ZeroMQ::Context>, L<ZeroMQ::Socket>, and 
L<ZeroMQ::Message> classes available as well.

=back

=head1 BASIC USAGE

To start using ZeroMQ, you need to create a context object, then as many ZeroMQ::Socket as you need:

    my $ctxt = ZeroMQ::Context->new;
    my $socket = $ctxt->socket( ... options );

You need to call C<bind()> or C<connect()> on the socket, depending on your usage. For example on a typical server-client model you would write on the server side:

    $socket->bind( "tcp://127.0.0.1:9999" );

and on the client side:

    $socket->connect( "tcp://127.0.0.1:9999" );

The underlying zeromq library offers TCP, multicast, in-process, and ipc connection patterns. Read the zeromq manual for more details on other ways to setup the socket.

When sending data, you can either pass a ZeroMQ::Message object or a Perl string. 

    # the following two send() calls are equivalent
    my $msg = ZeroMQ::Message->new( "a simple message" );
    $socket->send( $msg );
    $socket->send( "a simple message" ); 

In most cases using ZeroMQ::Message is redundunt, so you will most likely use the string version.

To receive, simply call C<recv()> on the socket

    my $msg = $socket->recv;

The received message is an instance of ZeroMQ::Message object, and you can access the content held in the message via the C<data()> method:

    my $data = $msg->data;

=head1 SERIALIZATION

ZeroMQ.pm comes with a simple serialization/deserialization mechanism.

To serialize, use C<register_write_type()> to register a name and an
associated callback to serialize the data. For example, for JSON we do
the following (this is already done for you in ZeroMQ.pm if you have
JSON.pm installed):

    use JSON ();
    ZeroMQ::register_write_type('json' => \&JSON::encode_json);
    ZeroMQ::register_read_type('json' => \&JSON::decode_json);

Then you can use C<send_as()> and C<recv_as()> to specify the serialization 
type as the first argument:

    my $ctxt = ZeroMQ::Context->new();
    my $sock = $ctxt->socket( ZMQ_REQ );

    $sock->send_as( json => $complex_perl_data_structure );

The otherside will receive a JSON encoded data. The receivind side
can be written as:

    my $ctxt = ZeroMQ::Context->new();
    my $sock = $ctxt->socket( ZMQ_REP );

    my $complex_perl_data_structure = $sock->recv_as( 'json' );

If you have JSON.pm (must be 2.00 or above), then the JSON serializer / 
deserializer is automatically enabled. If you want to tweak the serializer
option, do something like this:

    my $coder = JSON->new->utf8->pretty; # pretty print
    ZeroMQ::register_write_type( json => sub { $coder->encode($_[0]) } );
    ZeroMQ::register_read_type( json => sub { $coder->decode($_[0]) } );

Note that this will have a GLOBAL effect. If you want to change only
your application, use a name that's different from 'json'.

=head1 ASYNCHRONOUS I/O WITH ZEROMQ

By default ZeroMQ comes with its own zmq_poll() mechanism that can handle
non-blocking sockets. You can use this by calling zmq_poll with a list of
hashrefs:

    zmq_poll([
        {
            fd => fileno(STDOUT),
            events => ZMQ_POLLOUT,
            callback => \&callback,
        },
        {
            socket => $zmq_socket,
            events => ZMQ_POLLIN,
            callback => \&callback
        },
    ], $timeout );

Unfortunately this custom polling scheme doesn't play too well with AnyEvent.

As of zeromq2-2.1.0, you can use getsockopt to retrieve the underlying file
descriptor, so use that to integrate ZeroMQ and AnyEvent:

    my $socket = zmq_socket( $ctxt, ZMQ_REP );
    my $fh = zmq_getsockopt( $socket, ZMQ_FD );
    my $w; $w = AE::io $fh, 0, sub {
        while ( my $msg = zmq_recv( $socket, ZMQ_RCVMORE ) ) {
            # do something with $msg;
        }
        undef $w;
    };

=head1 NOTES ON MULTI-PROCESS and MULTI-THREADED USAGE

ZeroMQ works on both multi-process and multi-threaded use cases, but you need
to be careful bout sharing ZeroMQ objects.

For multi-process environments, you should not be sharing the context object.
Create separate contexts for each process, and therefore you shouldn't
be sharing the socket objects either.

For multi-thread environemnts, you can share the same context object. However
you cannot share sockets.

=head1 FUNCTIONS

=head2 version()

Returns the version of the underlying zeromq library that is being linked.
In scalar context, returns a dotted version string. In list context,
returns a 3-element list of the version numbers:

    my $version_string = ZeroMQ::version();
    my ($major, $minor, $patch) = ZeroMQ::version();

=head2 device($type, $sock1, $sock2)

=head2 register_read_type($name, \&callback)

Register a read callback for a given C<$name>. This is used in C<recv_as()>.
The callback receives the data received from the socket.

=head2 register_write_type($name, \&callback)

Register a write callback for a given C<$name>. This is used in C<send_as()>
The callback receives the Perl structure given to C<send_as()>

=head1 DEBUGGING XS

If you see segmentation faults, and such, you need to figure out where the error is occuring in order for the maintainers to figure out what happened. Here's a very very brief explanation of steps involved.

First, make sure to compile ZeroMQ.pm with debugging on by specifying -g:

    perl Makefile.PL -g
    make

Then fire gdb:

    gdb perl
    (gdb) R -Mblib /path/to/your/script.pl

When you see the crash, get a backtrace:

    (gdb) bt

=head1 CAVEATS

This is an early release. Proceed with caution, please report
(or better yet: fix) bugs you encounter.

This module has been tested againt B<zeromq 2.1.4>. Semantics of this
module rely heavily on the underlying zeromq version. Make sure
you know which version of zeromq you're working with.

=head1 SEE ALSO

L<ZeroMQ::Raw>, L<ZeroMQ::Context>, L<ZeroMQ::Socket>, L<ZeroMQ::Message>

L<http://zeromq.org>

L<http://github.com/lestrrat/ZeroMQ-Perl>

=head1 AUTHOR

Daisuke Maki C<< <daisuke@endeworks.jp> >>

Steffen Mueller, C<< <smueller@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

The ZeroMQ module is

Copyright (C) 2010 by Daisuke Maki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
