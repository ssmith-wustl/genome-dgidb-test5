package RefCov::Reference::Redundancy;

use strict;
use warnings;
use Carp;
use version; my $VERSION = qv( '0.0.1' );

# Global constants:
use constant TRUE   => 1;
use constant FALSE  => 0;
use constant MODULE => 'RefCov::Reference::Redundancy';

# UPDATES:
# Thu Jun 26 13:23:03 CDT 2008
#    Changed the way that calculations are made for the "redundancy"
#    metrics. There are essentially 2 metrics:
#       % redundancy of start sites [pluggable]
#       % redundancy of layers      [hard coded]


sub new {
    my $class = shift;

    my $self = {
                _start_site   => {},
                _total_layers => 0,
               };

    return bless ($self, $class);
}



sub add_layer {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start})      { croak MODULE . ' requires a "start" argument.'      }

    # Updates to the object instance.
    $self->{_start_site}->{ $arg{start} }++;
    $self->{_total_layers}++;
}



sub layers_total { return shift->{_total_layers} }



sub start_site_total { return scalar keys( %{ shift->{_start_site} } ) }



sub start_sites_unique {
    my ($self, %arg) = @_;

    # Optional arguments:
    my $max_depth = 1;  # default
    if ($arg{max_depth}) { $max_depth = $arg{max_depth} }

    my $start_sites_unique;
    foreach my $start (keys %{$self->{_start_site}}) {
        $start_sites_unique++ if ( $self->{_start_site}->{$start} <= $max_depth );
    }
    if (!$start_sites_unique) { $start_sites_unique = 'null' }  # no members

    return $start_sites_unique;
}



sub percent_redundancy_start_sites {
    my ($self, %arg) = @_;

    # Optional arguments:
    my $max_depth = 1;  # default
    if ($arg{max_depth}) { $max_depth = $arg{max_depth} }

    if ($self->start_sites_unique( max_depth => $max_depth ) ne 'null') {
        my $percent_redundancy =
            100 - ( ($self->start_sites_unique( max_depth => $max_depth ) / $self->start_site_total()) * 100 );
        $percent_redundancy = sprintf( "%.2f", $percent_redundancy );
        return $percent_redundancy;
    }
    else {
        return 'null';
    }
}



sub percent_redundancy_layers {
    my $self = shift;

    if ($self->layers_total() > 0) {
        my $percent_redundancy =
            100 - ( ($self->start_site_total() / $self->layers_total()) * 100 );
        $percent_redundancy = sprintf( "%.2f", $percent_redundancy );
        return $percent_redundancy;
    }
    else {
        return 'null';
    }
}




sub redundancy_stats {
    my ($self, %arg) = @_;

    # Optional arguments:
    my $max_depth = 1;  # default
    if ($arg{max_depth}) { $max_depth = $arg{max_depth} }

    # STATS:
    #       total layers
    #       start site total
    #       start site unique
    #       percent redundancy (start site)
    #       percent redundancy (reads)
    #       max depth value
    my @stats = (
                 $self->layers_total(),
                 $self->start_site_total(),
                 $self->start_sites_unique(             max_depth => $max_depth ),
                 $self->percent_redundancy_start_sites( max_depth => $max_depth ),
                 $self->percent_redundancy_layers(),
                 $max_depth,
                );
    return \@stats;  # [total, unique, percent, max depth]
}



sub redundancy_topology {
    my $self = shift;
    return $self->{_start_site};  # **NOTE** unordered start positions
}


1;  # end of package

__END__


=head1 NAME

RefCov::Reference::Redundancy - [One line description of module's purpose here]


=head1 VERSION

This document describes RefCov::Reference::Redundancy version 0.0.1


=head1 SYNOPSIS

    use RefCov::Reference::Redundancy;

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

RefCov::Reference::Redundancy requires no configuration files or environment variables.


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
C<bug-refcov-reference-basefrequency@rt.cpan.org>, or through the web interface at
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

