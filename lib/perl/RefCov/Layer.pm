package RefCov::Layer;

use strict;
use warnings;
use Carp;
use version; my $VERSION = qv( '0.0.1' );

# Global constants:
use constant TRUE   => 1;
use constant FALSE  => 0;
use constant MODULE => 'RefCov::Layer';

sub new {
    my ($class, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop} ) { croak MODULE . ' requires a "stop" argument.'  }

    my $self  = {
                 _start    => undef,
                 _stop     => undef,
                 _length   => undef,
                 _name     => undef,
                 _sequence => undef,
                };
    bless ($self, $class);

    # The layer name is optional:
    if ($arg{name}) { $self->{_name} = $arg{name} }

    # Sequence is optional:
    if ($arg{sequence}) { $self->{_sequence} = $arg{sequence} }

    # Set start/stop... flip if needed:
    (
     $self->{_start},
     $self->{_stop},
    ) = $self->_flip_coordinates(
                                 start => $arg{start},
                                 stop  => $arg{stop},
                                );

    # Length of layer:
    $self->{_length} = ($self->stop() - $self->start()) + 1;

    return $self;
}



sub start { return shift->{_start} }



sub stop { return shift->{_stop} }



sub layerlen { return shift->{_length} }



sub name { return shift->{_name} }



sub sequence { return shift->{_sequence} }



sub set_name {
    my ($self, $name) = @_;

    # Required arguments:
    if (!$name) { croak MODULE . ' requires a "name" argument.' }

    $self->{_name} = $name;

    return $self;
}



sub set_start {
    my ($self, $start) = @_;

    # Required arguments:
    if (!$start) { croak MODULE . ' requires a "start" argument.' }

    $self->{_start} = $start;

    return $self;
}



sub set_stop {
    my ($self, $stop) = @_;

    # Required arguments:
    if (!$stop) { croak MODULE . ' requires a "stop" argument.' }

    $self->{_stop} = $stop;

    return $self;
}



sub set_sequence {
    my ($self, $sequence) = @_;

    # Required arguments:
    if (!$sequence) { croak MODULE . ' requires a "sequence" argument.' }

    # Make sure that sequence length and layer length coordinates match:
    if ($self->layerlen() != length( $sequence )) {
        croak MODULE . ' sees discrepencies in raw sequence length and sequence coordinates.';
    }
    else {
        $self->{_sequence} = $sequence;
        return $self;
    }
}



sub is_sequence {
    my $self = shift;
    if ($self->{_sequence}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub is_name {
    my $self = shift;
    if ($self->{_name}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub _flip_coordinates {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' INTERNAL ERROR: "start" argument required.' }
    if (!$arg{stop} ) { croak MODULE . ' INTERNAL ERROR: "stop" argument required.'  }

    # Flip, if needed:
    my $arg_start = $arg{start};
    my $arg_stop  = $arg{stop};
    $arg{start} = ($arg_start > $arg_stop ) ? $arg_stop  : $arg_start;
    $arg{stop}  = ($arg_stop  < $arg_start) ? $arg_start : $arg_stop;
    return ($arg{start}, $arg{stop});
}



1;  # end of package


__END__


=head1 NAME

RefCov::Layer - [One line description of module's purpose here]


=head1 VERSION

This document describes RefCov::Layer version 0.0.1


=head1 SYNOPSIS

    use RefCov::Layer;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

RefCov::Layer requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-refcov-layer@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Todd Wylie

C<< <todd@monkeybytes.org> >>

L<< http://www.monkeybytes.org >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007, Todd Wylie C<< <todd@monkeybytes.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See perlartistic.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NOTE

This software was written using the latest version of GNU Emacs, the
extensible, real-time text editor. Please see
L<http://www.gnu.org/software/emacs> for more information and download
sources.
