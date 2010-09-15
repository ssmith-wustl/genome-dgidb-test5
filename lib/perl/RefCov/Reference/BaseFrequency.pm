package RefCov::Reference::BaseFrequency;

use strict;
use warnings;
use Carp;
use version; my $VERSION = qv( '0.0.1' );

# Global constants:
use constant TRUE   => 1;
use constant FALSE  => 0;
use constant MODULE => 'RefCov::Reference::BaseFrequency';

sub new {
    my ($class, %arg) = @_;

    my $self  = {
                 _frequency => undef,
                };

    return bless ($self, $class);
}



sub is_base_frequency {
    my $self = shift;
    if ($self->{_frequency}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub _is_position {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    if ($self->{_frequency}->{$arg{pos}}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub base_frequency {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    # Return array reference to nucleotide counts: [A, C, G, T, N, -]
    unless ($self->_is_position( pos => $arg{pos} )) {
        $self->{_frequency}->{$arg{pos}} = [ 0, 0, 0, 0, 0 ];
    }

    return $self->{_frequency}->{$arg{pos}};
}



sub base_frequency_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Return a hash reference to a span of nucleotide counts, where key id the
    # pos. along the reference sequence from START to STOP, and the entry is an
    # anonymous array of the following type: [A, C, G, T, N, -]
    my %base_span;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_position( pos => $_ )) {
            $base_span{$_} = $self->base_frequency( pos => $_ );
        }
        else {
            $base_span{$_} = [ 0, 0, 0, 0, 0 ];  # [A, C, G, T, N, -]
        }
    }

    return \%base_span;
}



sub base_heterozygosity_consensus {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos})   { croak MODULE . ' requires a "pos" argument.'   }

    # Optional arguments:
    my $filter = FALSE;
    if ($arg{min_depth} && $arg{min_ratio}) {
        $filter = TRUE;
    }
    else {
        # Did user only pass 1 argument?
        if ($arg{min_depth} || $arg{min_ratio}) {
            if (!$arg{min_depth}) { croak MODULE . ' requires both "min_depth" and "min_ratio".' }
            if (!$arg{min_ratio}) { croak MODULE . ' requires both "min_depth" and "min_ratio".' }
        }
    }

    # Determine the top 2 dominant base frequencies per position and return a
    # consensus call to the user along with the winning ratios. Returns a
    # pipe-delimited string of the following values: 1) depth of coverage for
    # all base frequencies at the ref position; 2) top 2 bases based on
    # frequency, seperated by a '/' character; 3) ratio of the top 2 bases by
    # base frequency; 4) ratio percent form.
    #
    # EXAMPLES:
    # non-refseq version
    #         28|A/T|20:8|0.4
    #         2000|A|100|-
    #         100|G/C|50:50|1
    #         0|./.|0|0
    # refseq version
    #         A|*|100|G/C|50:50|1
    #         G|-|100|G/C|50:50|1
    map {$_ = 0} my ($consensus, $depth);
    if ($self->_is_position( pos => $arg{pos} )) {
        my (
            $A,
            $C,
            $G,
            $T,
            $N,
            $dash,
           ) = @{$self->base_frequency( pos => $arg{pos} )};
        map {$depth += $_} @{$self->base_frequency( pos => $arg{pos} )};
        my %call;
        push (@{$call{$A}},    'A');
        push (@{$call{$C}},    'C');
        push (@{$call{$G}},    'G');
        push (@{$call{$T}},    'T');
        push (@{$call{$N}},    'N');
        push (@{$call{$dash}}, '-');

        map {$_ = 0} my ($first_place, $second_place, $i);
        foreach my $call (sort {$b <=> $a} keys %call) {
            $i++;
            if ($i == 1) { $first_place  = $call }
            if ($i == 2) { $second_place = $call }
        }

        # --------------------------------
        # Frequency Evaluation
        # --------------------------------
        # [1]  first coverage only
        #      - 100% call
        #      - shift a tie
        # [2]  both coverage
        #      - first ties, shift
        #      - second ties
        #      - not tie
        #      - both tie, shift first
        # [3]  ERROR!
        # [4]  no coverage
        # --------------------------------
        if (
            $first_place  >  0 &&
            $second_place == 0
           ) {
            # [1]  first coverage only
            if (scalar( @{$call{$first_place}} ) == 1) {
                # - 100% call
                $consensus = join (
                                   '|',
                                   $depth,                 # depth
                                   @{$call{$first_place}}, # bases
                                   '1',                    # ratio
                                   '-',                    # percent
                                  );
            }
            elsif (scalar( @{$call{$first_place}} ) > 1) {
                # - shift a tie
                my $bases   = join ('/', @{$call{$first_place}});
                my $ratio   = $first_place . ':' . $first_place;
                my $percent = '1';
                $consensus = join (
                                   '|',
                                   $depth,
                                   $bases,
                                   $ratio,
                                   $percent,
                                  );
            }
            else {
                croak MODULE . ' INTERNAL ERROR: cannot evaluate heterozygosity (first coverage).';
            }
        }
        elsif (
               $first_place  > 0 &&
               $second_place > 0
              ) {
            # [2]  both coverage
            if (
                scalar( @{$call{$first_place}}  )  > 1 &&
                scalar( @{$call{$second_place}} ) == 1
               ) {
                # - first ties, shift
                my $bases     = join ('/', @{$call{$first_place}});
                my $ratio     = $first_place . ':' . $first_place;
                my $percent   = '1';
                $consensus = join (
                                   '|',
                                   $depth,
                                   $bases,
                                   $ratio,
                                   $percent,
                                  );
            }
            elsif (
                   scalar( @{$call{$first_place}}  ) == 1 &&
                   scalar( @{$call{$second_place}} )  > 1
                  ) {
                # - second ties
                my $bases = join (q//, @{$call{$second_place}});
                $bases      = '(' . $bases . ')';
                $bases      = "@{$call{$first_place}}" . '/' . $bases;
                my $ratio   = $first_place . ':' . $second_place;
                my $percent = sprintf( "%2.3f", ($second_place / $first_place) );
                $consensus  = join (
                                    '|',
                                    $depth,
                                    $bases,
                                    $ratio,
                                    $percent,
                                   );
            }
            elsif (
                   scalar( @{$call{$first_place}}  ) == 1 &&
                   scalar( @{$call{$second_place}} ) == 1
                  ) {
                # - no ties
                my $bases   = "@{$call{$first_place}}" . '/' . "@{$call{$second_place}}";
                my $ratio   = $first_place . ':' . $second_place;
                my $percent = sprintf( "%2.3f", ($second_place / $first_place) );
                $consensus  = join (
                                    '|',
                                    $depth,
                                    $bases,
                                    $ratio,
                                    $percent,
                                   );
            }
            elsif (
                   scalar( @{$call{$first_place}}  ) > 1 &&
                   scalar( @{$call{$second_place}} ) > 1
                  ) {
                # - both tie, shift first
                my $bases     = join ('/', @{$call{$first_place}});
                my $ratio     = $first_place . ':' . $first_place;
                my $percent   = '1';
                $consensus = join (
                                   '|',
                                   $depth,
                                   $bases,
                                   $ratio,
                                   $percent,
                                  );
            }
            else {
                croak MODULE . ' INTERNAL ERROR: cannot evaluate heterozygosity (both coverage).';
            }
        }
        else {
            # [3] ERROR!
            croak MODULE . ' INTERNAL ERROR: cannot evaluate heterozygosity condition (unknown).';
        }

    }

    # [4] no coverage
    $consensus = '0|-/-|0|0' if (!$consensus);

    # EVALUATION & RETURN
    unless ($filter == TRUE) {
        return $consensus;
    }
    else {
        my @eval  = split ('\|', $consensus);
        my $depth = $eval[0];
        my $ratio = $eval[3];
        if (
            $ratio eq '-' ||  # no cov
            $ratio == 1       # perfect single allele
           ) {
            return;  # filtered out
        }
        elsif (
               $depth >= $arg{min_depth} &&
               $ratio >= $arg{min_ratio}
              ) {
            return $consensus;
        }
        else {
            return;  # filtered out
        }
    }
}



sub base_consensus {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    # Determine the dominant base per position and return the consensus call to
    # the user. In cases were there are ties, return a value with the tied bases
    # seperated by a colon. Default for non-covered is a '0' character.
    #
    # EXAMPLES:
    #         0       =  no base (coverage)
    #         255:A   =  A is the dominant base (255 count)
    #         55:A:C  =  A,C tied (55 count)
    #         5:A:C:T =  A,C,T tied (5 count)
    my $consensus = '0';
    if ($self->_is_position( pos => $arg{pos} )) {
        my (
            $A,
            $C,
            $G,
            $T,
            $N,
            $dash,
           ) = @{$self->base_frequency( pos => $arg{pos} )};

        my %call;
        push (@{$call{$A}},    'A');
        push (@{$call{$C}},    'C');
        push (@{$call{$G}},    'G');
        push (@{$call{$T}},    'T');
        push (@{$call{$N}},    'N');
        push (@{$call{$dash}}, '-');

        CALL:
        foreach my $call (sort {$b <=> $a} keys %call) {
            $consensus = join (':', @{$call{$call}});
            $consensus = $call . ':' . $consensus;
            last CALL;
        }
    }

    return $consensus;
}



sub compose {
    my ($self, $freq_object) = @_;

    # Accepts a BaseFrequency class object as input and updates the current
    # BaseFrequency object via composition of values.
    foreach my $pos (keys %{$freq_object->{_frequency}}) {
        if ($self->_is_position( pos => $pos )) {
            # Prior existence:
            $self->{_frequency}->{$pos}[0] += $freq_object->{_frequency}->{$pos}[0];  # A
            $self->{_frequency}->{$pos}[1] += $freq_object->{_frequency}->{$pos}[1];  # C
            $self->{_frequency}->{$pos}[2] += $freq_object->{_frequency}->{$pos}[2];  # G
            $self->{_frequency}->{$pos}[3] += $freq_object->{_frequency}->{$pos}[3];  # T
            $self->{_frequency}->{$pos}[4] += $freq_object->{_frequency}->{$pos}[4];  # N
            $self->{_frequency}->{$pos}[5] += $freq_object->{_frequency}->{$pos}[5];  # -
        }
        else {
            # New entry:
            $self->{_frequency}->{$pos} = [ @{$freq_object->{_frequency}->{$pos}} ];
        }

    }

    return $self;
}



sub base_heterozygosity_consensus_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Return a hash reference to a span of base consensus calls; each value in
    # the hash represents the most prevalent 2 base frequency members.
    my %consensus_span;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_position( pos => $_ )) {
            $consensus_span{$_} = $self->base_heterozygosity_consensus( pos => $_ );
        }
        else {
            $consensus_span{$_} = '0|-/-|0';
        }
    }

    return \%consensus_span;
}



sub base_consensus_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Return a hash reference to a span of base consensus calls; each value in
    # the hash represents the most prevalent base based on coverage depth, tied
    # bases, or no coverage.
    my %consensus_span;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_position( pos => $_ )) {
            $consensus_span{$_} = $self->base_consensus( pos => $_ );
        }
        else {
            $consensus_span{$_} = 'X';
        }
    }

    return \%consensus_span;
}



sub save_FASTCcon_file {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{name})  { croak MODULE . ' requires a "name" argument.'  }
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }
    if (!$arg{out})   { croak MODULE . ' requires a "out" argument.'   }

    # No line wrapping:
    my $out = IO::File->new( ">$arg{out}" ) or croak 'Could not save FASTCcon file.';
    print $out ">$arg{name}\n";
    for ($arg{start}..$arg{stop}) {
        print $out $self->base_consensus( pos => $_ ) . q/ /;
    }
    print "\n";

    return $self;
}



sub print_FASTCcon {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{name})  { croak MODULE . ' requires a "name" argument.'  }
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # No line wrapping:
    print ">$arg{name}\n";
    for ($arg{start}..$arg{stop}) {
        print $self->base_consensus( pos => $_ ) . q/ /;
    }
    print "\n";

    return $self;
}



sub add_base_freq {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos} ) { croak MODULE . ' requires a "pos" argument. '               }
    if (!$arg{base}) { croak MODULE . ' requires a "base" argument [A|C|G|T|N|-].' }
    $arg{base} = uc( $arg{base} );

    # Uniform index lookup for nucletide placement:
    my %nucleotide_index = (
                            'A' => 0,
                            'C' => 1,
                            'G' => 2,
                            'T' => 3,
                            'N' => 4,
                            '-' => 5,
                           );

    # Update the object for nucleotide count addition, prime if needed:
    unless ($self->_is_position( pos => $arg{pos} )) {
        # Prime all base categories for given position:
        $self->{_frequency}->{$arg{pos}}[0] = 0;  # A
        $self->{_frequency}->{$arg{pos}}[1] = 0;  # C
        $self->{_frequency}->{$arg{pos}}[2] = 0;  # G
        $self->{_frequency}->{$arg{pos}}[3] = 0;  # T
        $self->{_frequency}->{$arg{pos}}[4] = 0;  # N
        $self->{_frequency}->{$arg{pos}}[5] = 0;  # -
        $self->{_frequency}->{$arg{pos}}[ $nucleotide_index{$arg{base}} ]++;
    }
    else {
        # Update count of nucleotide at given position:
        $self->{_frequency}->{$arg{pos}}[ $nucleotide_index{$arg{base}} ]++;
    }

    return $self;
}



1;  # end of package


__END__


=head1 NAME

RefCov::Reference::BaseFrequency - [One line description of module's purpose here]


=head1 VERSION

This document describes RefCov::Reference::BaseFrequency version 0.0.1


=head1 SYNOPSIS

    use RefCov::Reference::BaseFrequency;

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

RefCov::Reference::BaseFrequency requires no configuration files or environment variables.


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
