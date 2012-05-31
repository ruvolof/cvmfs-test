package ZeroMQ::Context;
use strict;
use ZeroMQ::Raw ();

sub new {
    my ($class, $nthreads) = @_;
    if (! defined $nthreads || $nthreads <= 0) {
        $nthreads = 1;
    }

    bless {
        _ctxt => ZeroMQ::Raw::zmq_init($nthreads),
    }, $class;
}

sub ctxt {
    $_[0]->{_ctxt};
}

sub socket {
    return ZeroMQ::Socket->new(@_); # $_[0] should contain the context
}

sub term {
    my $self = shift;
    ZeroMQ::Raw::zmq_term($self->ctxt);
}

1;

__END__

=head1 NAME

ZeroMQ::Context - A 0MQ Context object

=head1 SYNOPSIS

  use ZeroMQ qw/:all/;
  
  my $cxt = ZeroMQ::Context->new;
  my $sock = ZeroMQ::Socket->new($cxt, ZMQ_REP);

=head1 DESCRIPTION

Before opening any 0MQ Sockets, the caller must initialise
a 0MQ context.

=head1 METHODS

=head2 new($nthreads)

Creates a new C<ZeroMQ::Context>.

Optional arguments: The number of io threads to use. Defaults to 1.

=head2 term()

Terminates the current context. You *RARELY* need to call this yourself,
so don't do it unless you know what you're doing.

=head2 socket($type)

Short hand for ZeroMQ::Socket::new. 

=head2 ctxt

Return the underlying ZeroMQ::Raw::Context object

=head1 CAVEATS

While in principle, C<ZeroMQ::Context> objects are thread-safe,
they are currently not cloned when a new Perl ithread is spawned.
The variables in the new thread that contained the context in
the parent thread will be a scalar reference to C<undef>
in the new thread. This could be fixed with better control
over the destructor calls.

=head1 SEE ALSO

L<ZeroMQ>, L<ZeroMQ::Socket>

L<http://zeromq.org>

L<ExtUtils::XSpp>, L<Module::Build::WithXSpp>

=head1 AUTHOR

Daisuke Maki E<lt>daisuke@endeworks.jpE<gt>

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

The ZeroMQ module is

Copyright (C) 2010 by Daisuke Maki

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
