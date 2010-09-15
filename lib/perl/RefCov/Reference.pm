package RefCov::Reference;

use strict;
use warnings;
use Carp;
use IO::File;
use version; my $VERSION = qv( '0.0.1' );

# Global constants:
use constant TRUE   => 1;
use constant FALSE  => 0;
use constant MODULE => 'RefCov::Reference';

sub new {
    my ($class, %arg) = @_;

    # LEGAL ARGUMENTS:
    # --> name
    # --> start
    # --> stop
    # --> thaw
    # --> thaw_compose
    # --> glue

    if ($arg{thaw}) {
        # Thaw a single frozen coverage object and set object:
	use Storable;
        use Storable qw( nstore store_fd nstore_fd freeze thaw dclone );
        my $self  = retrieve( $arg{thaw} );
        return bless ($self, $class);
    }
    elsif ($arg{thaw_compose}) {
        # Compose the provided list of storable files onto each other and return
        # the composite object. MUST HAVE SAME REFERENCE "name" and "reflen"!!!
	my $self;
        $self = _thaw_compose(
                              storable_files => $arg{thaw_compose},
                             );
        return bless ($self, $class);
    }
    elsif ($arg{glue}) {
        # The user is passing reference fragments which we will order, validate,
        # and glue together. Each fragment must have the same identifying name
        # and and be exact continuations of the previous fragment--i.e., no
        # overlaps or gaps allowed.
        my $self;
        $self = _glue(
                      glue => $arg{glue},
                     );
        return bless ($self, $class);
    }
    else {
        # New object, validate arguments:
        if (!$arg{name} ) { croak MODULE . ' requires a "name" argument.'  }
        if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
        if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

        # Include classes for potential lazy loading:
        use RefCov::Reference::BaseFrequency;
        use RefCov::Reference::Redundancy;
        use RefCov::Layer;
        my $self  = {
                     _ref_name       => $arg{name},
                     _start          => $arg{start},
                     _stop           => $arg{stop},
                     _reflen         => ($arg{stop} - $arg{start}) + 1,
                     _ref_coverage   => undef,
                     _layer_names    => undef,  # lazy load (read sequence)
                     _ranges         => undef,
                     _base_frequency => RefCov::Reference::BaseFrequency->new(),  # lazy load (frequency)
                     _redundancy     => RefCov::Reference::Redundancy->new(),     # lazy load (redundancy)
                    };
        bless ($self, $class);

        # OPTIONAL:
        # The original reference sequence may be sent to this class as a linear
        # string. This could potentially lead to heavy-weight objects (i.e., for
        # chromosome size references)... so consider this when providing the
        # refseq string. The refseq--if present--will automatically be included
        # in base frequency and heterozygosity function outputs.
        if ($arg{sequence}) {
            if (length($arg{sequence}) != $self->reflen()) {
                croak MODULE . ' reference sequence and reflen are not equal in length';
            }
            else {
                $self->{_refseq} = $arg{sequence};
            }
        }
        return $self;
    }
}



sub name { return shift->{_ref_name} }



sub start { return shift->{_start} }



sub stop { return shift->{_stop} }



sub reflen { return shift->{_reflen} }



sub refseq {
    my $self = shift;
    if ($self->is_refseq() == 1) {
        return $self->{_refseq};
    }
    else {
        return FALSE;
    }
}



sub is_refseq {
    my $self = shift;
    if ($self->{_refseq}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub layer_read {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a start argument.' }
    if (!$arg{stop} ) { croak MODULE . ' requires a stop argument.'  }

    # Initialize a Layer class object:
    my $myLayer = RefCov::Layer->new(
                                     start => $arg{start},
                                     stop  => $arg{stop},
                                    );
    if (defined $arg{sequence}  ) { $myLayer->set_sequence(          $arg{sequence}       ) }
    if (defined $arg{layer_name}) { $myLayer->set_name(              $arg{layer_name}     ) }
    if (defined $arg{redundancy}) { $self->{_redundancy}->add_layer( start => $arg{start} ) }

    # Are the two values in range?
    #
    #        |==================|        REFERENCE FOOTPRINT
    #             |-------|              layer [OK-subsumed]
    #     |-------|                      layer [OK-truncate]
    #                     |-------|      layer [OK-truncate]
    #     |------------------------|     layer [OK-truncate]
    # |---|                              layer [BAD-external]
    #                             |---|  layer [BAD-external]
    my $add_coverage = FALSE;
    if (
        ($myLayer->start() >= $self->start()) &&
        (($myLayer->stop() <= $self->stop()))
       ) {
	# Subsumed:
	$add_coverage = TRUE;
    }
    elsif (
           ($myLayer->start() < $self->start())  &&
           (($myLayer->stop() >= $self->start()) &&
            ($myLayer->stop() <= $self->stop()))
          ) {
	# Truncate start-side:
	$myLayer->set_start( $self->start() );
	$add_coverage = TRUE;
    }
    elsif (
           ($myLayer->start() >= $self->start()   &&
            ($myLayer->start() <= $self->stop())) &&
           (($myLayer->stop() > $self->stop()))
          ) {
	# Truncate stop-side:
	$myLayer->set_stop( $self->stop() );
	$add_coverage = TRUE;
    }
    elsif (
           ($myLayer->start() < $self->start()) &&
           (($myLayer->stop() > $self->stop()))
          ) {
	# Truncate start-side & stop-side:
	$myLayer->set_start( $self->start() );
	$myLayer->set_stop(  $self->stop()  );
	$add_coverage     = TRUE;
    }
    elsif (
           ($myLayer->start() < $self->start()) &&
           (($myLayer->stop() < $self->start()))
          ) {
	# Out of bounds downstream:
	$add_coverage = FALSE;
    }
    elsif (
           ($myLayer->start() > $self->stop()) &&
           (($myLayer->stop() > $self->stop()))
          ) {
	# Out of bounds upstream:
	$add_coverage = FALSE;
    }
    else {
	$add_coverage = FALSE;
    }

    # Add coverage to the reference sequence.
    if ($add_coverage eq TRUE) {
        for ($myLayer->start()..$myLayer->stop()) {
            if ($self->_is_covered( pos => $_)) {
                $self->_add_depth( pos => $_ );
                if ($myLayer->is_name()) { $self->{_layer_names}->{$myLayer->name()} = [ $myLayer->start(), $myLayer->stop() ] }
            }
            else {
                $self->_first_coverage( pos => $_);
                if ($myLayer->is_name()) { $self->{_layer_names}->{$myLayer->name()} = [ $myLayer->start(), $myLayer->stop() ] }
            }
        }
    }

    # Update nucleotide breakdown totals (if appropriate) across the length
    # of the incoming sequence.
    if ($myLayer->is_sequence()) {

        # Must truncate the layer sequence on the STOP side to match that of
        # the reference footprint's length--due to potential padding in the
        # in the alignment sequence. EX:
        #
        # REF      TTCTCAAAAGAGGACATACAAAAGGCAAACAGATGTATTGAAA  (43)
        # SUBJECT  TTCTCAAAAGAGGACATACAAAAGGCAAACAGATGTAT-TGAAA (44)
        # LAYER    TTCTCAAAAGAAGACATACCAATGGCCAACAG--GTATATGAAA (44)
        if (length( $myLayer->sequence() ) > $self->reflen()) {
            $myLayer->sequence() = substr( $myLayer->sequence(), 0, $self->reflen() );
        }
        my $pos_i = $myLayer->start() - 1;
        foreach my $pos (split ('', $myLayer->sequence())) {
            $pos_i++;
            $self->{_base_frequency}->add_base_freq(
                                                    pos  => $pos_i,
                                                    base => $pos,
                                                   );
        }
    }

    return $self;
}



sub save_ranges_YAML {
    my ($self, $out) = @_;

    # Required arguments:
    if (!$out) { croak MODULE . ' requires an "out" argument.' }

    # Save a YAML document of ranges/members:
    unless($self->{_ranges}) { $self->_set_ranges() }  # lazy load

    # YAML header:
    my $output = IO::File->new( ">$out" ) or croak MODULE . ' could not save YAML file.';
    print $output "---\n";
    print $output "REF: "       . $self->name()  . "\n";
    print $output "REF START: " . $self->start() . "\n";
    print $output "REF STOP: "  . $self->stop()  . "\n";
    print $output "RANGES:\n";

    my $range_i    = 0;
    my $range_last = scalar keys %{$self->{_ranges}};
    foreach my $span (sort {$a <=> $b} keys %{$self->{_ranges}}) {
	$range_i++;
	print $output "\n";
	print $output "  # (range $range_i/$range_last)\n";
	print $output "  $range_i:\n";

	# Required arguments:
        unless ($self->_is_layer_names()) { croak MODULE . ' called null layer names; perhaps you forgot to pass "layer_name" in layer_read() method?' }
	print $output "    START: " . $self->{_ranges}->{$span}->{start} . "\n";
	print $output "    STOP: "  . $self->{_ranges}->{$span}->{stop}  . "\n";
	print $output "    LENGTH: " . (($self->{_ranges}->{$span}->{stop} - $self->{_ranges}->{$span}->{start}) + 1) . "\n";
	print $output "    MEMBERS:\n";

	# Membership evaluation of reads:
	my $membership = {};
	foreach my $query (sort keys %{$self->{_layer_names}}) {
	    if (
		$self->{_layer_names}->{$query}[0] >= $self->{_ranges}->{$span}->{start} &&
		$self->{_layer_names}->{$query}[1] <= $self->{_ranges}->{$span}->{stop}
		) {
		$membership->{$query}->{start}  = $self->{_layer_names}->{$query}[0];
		$membership->{$query}->{stop}   = $self->{_layer_names}->{$query}[1];
		$membership->{$query}->{length} = ($self->{_layer_names}->{$query}[1] - $self->{_layer_names}->{$query}[0]) + 1;
	    }
	}
	my $member_i = 0;
	foreach my $member (sort {$membership->{$b}->{length} <=> $membership->{$a}->{length}} keys %{$membership}) {
	    $member_i++;
	    print $output "        $member_i:\n";
	    print $output "          NAME: "    . $member                          . "\n";
	    print $output "          LENGTH: "  . $membership->{$member}->{length} . "\n";
	    print $output "          START: "   . $membership->{$member}->{start}  . "\n";
	    print $output "          STOP: "    . $membership->{$member}->{stop}   . "\n";
	}
    }
    print $output "...\n";  # end of YAML document

    return $self;
}



sub base_frequency {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_frequency( pos => $arg{pos} );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub save_FASTCcon_file {
    my ($self, $out) = @_;

    # Required arguments:
    if (!$out) { croak MODULE . ' requires an "out" argument.' }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        $self->{_base_frequency}->save_FASTCcon_file(
                                                     name  => $self->name(),
                                                     start => $self->start(),
                                                     stop  => $self->stop(),
                                                     out   => $out,
                                                    );
        return $self;
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub base_frequency_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_frequency_span(
                                                             start => $arg{start},
                                                             stop  => $arg{stop},
                                                            );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub base_consensus {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_consensus( pos => $arg{pos} );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub base_heterozygosity_consensus {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_heterozygosity_consensus( pos => $arg{pos} );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub print_consensus_FASTA {
    my $self = shift;

    # Calls the base_consensus() function along the length of the coverage
    # object.
    my $sequence;
    for ($self->start()..$self->stop()) {
        my $consensus = $self->base_consensus( pos => $_ );
        $consensus =~ s/[\:0-9]//g;  # only want base portion
        $consensus = '.' if (!$consensus);
        if (length( $consensus ) > 1) { $consensus = '(' . $consensus . ')' }
        $sequence .= $consensus;
    }

    # FASTAParse
    #   Author: Todd Wylie
    #   URL:    http://cpan.uwinnipeg.ca/~twylie/FASTAParse
    use FASTAParse;

    # Make a FASTA object of the consensus:
    my $id = $self->name();
    my $stats   = join (q/  /, @{$self->generate_stats()});
    my $reflen  = 'length: ' . $self->reflen();
    my $span    = 'span: ' . '(' . $self->start() . '-' . $self->stop() . ')';
    my $myFASTA = FASTAParse->new();
    $myFASTA->format_FASTA(
                           id       => $id,
                           sequence => $sequence,
                           comments => [
                                        $reflen,
                                        $span,
                                        $stats,
                                       ],
                          );
    $myFASTA->print();

    return $self;
}



sub base_consensus_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_consensus_span(
                                                             start => $arg{start},
                                                             stop  => $arg{stop},
                                                            );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub base_heterozygosity_consensus_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop})  { croak MODULE . ' requires a "stop" argument.'  }

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        return $self->{_base_frequency}->base_heterozygosity_consensus_span(
                                                                            start => $arg{start},
                                                                            stop  => $arg{stop},
                                                                           );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }
}



sub print_FASTCcon {
    my $self = shift;

    # Delegate to the BaseFrequency class:
    if ($self->{_base_frequency}->is_base_frequency()) {
        $self->{_base_frequency}->print_FASTCcon(
                                                 name  => $self->name(),
                                                 start => $self->start(),
                                                 stop  => $self->stop(),
                                                );
    }
    else {
        croak MODULE . ' called null base frequency; perhaps you forgot to pass "sequence" in layer_read() method?'
    }

    return $self;
}



sub _is_covered {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    if ($self->{_ref_coverage}->{$arg{pos}}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub _is_layer_names {
    my $self = shift;
    if ($self->{_layer_names}) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}



sub _add_depth {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    $self->{_ref_coverage}->{$arg{pos}} = ++$self->{_ref_coverage}->{$arg{pos}};

    return $self;
}



sub _first_coverage {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    $self->{_ref_coverage}->{$arg{pos}} = 1;

    return $self;
}



sub depth {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    return $self->{_ref_coverage}->{$arg{pos}};
}



sub depth_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop} ) { croak MODULE . '  requires a "stop" argument.'  }

    # Return an array of the span coverage.
    my @span_depths;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_covered( pos => $_ )) {
            push (@span_depths, $self->depth( pos => $_ ));
        }
        else {
            push (@span_depths, '0');
        }
    }
    return \@span_depths;
}



sub print_FASTC {
    my ($self, %arg) = @_;

    # No line wrapping:
    print '>' . $self->name() . "\n";
    for ($self->start()..$self->stop()) {
        if ($self->_is_covered( pos => $_ )) {
            print $self->depth( pos => $_ ) . q/ /;
        }
        else {
            print '0' . q/ /;
        }
    }
    print "\n";

    return $self;
}



sub generate_stats {
    my ($self, %arg) = @_;

    # Optional redundancy max_depth may be passed:
    my $max_depth = 1;
    if ($arg{max_depth}) { $max_depth = $arg{max_depth} }

    # Validate min_depth as numeric (if passed) & greater than 0:
    if ($arg{min_depth}) {
        if (
            $arg{min_depth} !~ /^\d+$/ ||
            $arg{min_depth} =~ /\D+/
           ) {
            croak MODULE . ' wants an integer value for min_depth.';
        }
        else {
            $arg{min_depth} = int( $arg{min_depth} );
        }
    }

    # Math::NumberCruncher
    #   Author: Kurt Kincaid
    #   URL:    http://cpan.uwinnipeg.ca/search?query=numbercruncher&mode=dist
    use Math::NumberCruncher;

    my (@position_depths, @gap_sizes);
    my $total_covered      = 0;
    my $current_gap_length = 0;
    my $discarded_bases    = 0;
    my $min_depth          = 0;

    # Walk entire length of footprint and do calculations
    for ($self->start()..$self->stop()) {
        if ($self->_is_covered( pos => $_ )) {
            # Min. Depth check.
            if ($arg{min_depth}) {
                $min_depth = $arg{min_depth};
                if ($self->depth( pos => $_ ) < $arg{min_depth}) {
                    # FAILED min. depth filter.
                    $discarded_bases++;
                    push (@position_depths, '0');
                    $current_gap_length++;
                }
                else {
                    # PASSED min. depth filter.
                    $total_covered++;
                    push (@position_depths, $self->depth( pos => $_ ) );
                    if ( $current_gap_length != 0 ) {
                        push (@gap_sizes, $current_gap_length);
                        $current_gap_length = 0;
                    }
                }
            }
            else {
                # Non-zero instance:
                $total_covered++;
                push (@position_depths, $self->depth( pos => $_ ) );
                if ( $current_gap_length != 0 ) {
                    push (@gap_sizes, $current_gap_length);
                    $current_gap_length = 0;
                }
            }
        }
        else {
	    # No alignment:
	    push (@position_depths, '0');
	    $current_gap_length++;
        }
    }

    # If tail of alignment was in a gap, we need to push that last gap
    # length into our @gap_sizes array
    if ($current_gap_length != 0) {
	push (@gap_sizes, $current_gap_length);
	$current_gap_length = 0;
    }

    # Coverage calculations:
    my $mean_pos_depth;
    my $med_pos_depth;
    my $stddev_pos_depth;
    my $mean_gap_size;
    my $med_gap_size;
    my $stddev_gap_size;
    unless (defined $position_depths[0]) {
	$mean_pos_depth   = "0";
	$stddev_pos_depth = "NaN";
	$med_pos_depth    = "0";
    }
    else {
	$mean_pos_depth   = Math::NumberCruncher::Mean(              \@position_depths );
	$stddev_pos_depth = Math::NumberCruncher::StandardDeviation( \@position_depths );
	$med_pos_depth    = Math::NumberCruncher::Median(            \@position_depths ),
    }
    unless (defined $gap_sizes[0]) {
	$mean_gap_size   = "0";
	$stddev_gap_size = "NaN";
	$med_gap_size    = "0";
    }
    else {
	$mean_gap_size   = Math::NumberCruncher::Mean(              \@gap_sizes );
	$stddev_gap_size = Math::NumberCruncher::StandardDeviation( \@gap_sizes );
	$med_gap_size    = Math::NumberCruncher::Median(            \@gap_sizes ),
    }

    # Redundancy stats:
    map {$_ = 'null'} my ($layers_total, $layers_unique, $percent_redundancy);
    if ($self->{_redundancy}) {
        $layers_total       = $self->{_redundancy}->layers_total();
        $layers_unique      = $self->{_redundancy}->start_sites_unique( max_depth => $max_depth );
        $percent_redundancy = $self->{_redundancy}->percent_redundancy_start_sites( max_depth => $max_depth );
    }

    # FORMAT:
    # Percent of Reference Bases Covered
    # Total Number of Reference Bases
    # Total Number of Covered Bases
    # Number of Missing Bases
    # Average Coverage Depth
    # Standard Deviation Average Coverage Depth
    # Median Coverage Depth
    # Number of Gaps
    # Average Gap Length
    # Standard Deviation Average Gap Length
    # Median Gap Length
    # Min. Depth Filter
    # Discarded Bases (Min. Depth Filter)
    # Max. Unique Filter
    # Total Number of Reads Layered
    # Total Number of Unique Start Site Reads Layered
    # Percent Redundancy of Read Layers
    sub _round { return sprintf( "%.2f", shift ) }
    my @stats = (
                 _round( ($total_covered / $self->reflen()) * 100 ),
                 $self->reflen(),
                 $total_covered,
                 $self->reflen() - $total_covered,
                 _round( $mean_pos_depth ),
                 _round( $stddev_pos_depth ),
                 _round( $med_pos_depth ),
                 scalar @gap_sizes,
                 _round( $mean_gap_size ),
                 _round( $stddev_gap_size ),
                 _round( $med_gap_size ),
                 $min_depth . 'x',
                 $discarded_bases,
                 $max_depth,
                 $layers_total,
                 $layers_unique,
                 $percent_redundancy,
                );

    return \@stats;
}



sub save_FASTC_file {
    my ($self, $fastc_file) = @_;

    # Validate arguments:
    if (!$fastc_file) { croak MODULE . ' requires a file name for writing to.'  }

    # Write out the entire sequence, including positions with zero coverage.
    my $out = IO::File->new( ">$fastc_file" ) or croak MODULE . ' could not save coverage file.';
    print $out '>' . $self->name() . "\n";
    for ($self->start()..$self->stop()) {
        if ($self->_is_covered( pos => $_ )) {
            print $out $self->depth( pos => $_ ) . q/ /;
        }
        else {
            print $out '0' . q/ /;
        }
    }
    print $out "\n";
    close( $out );

    return $self;
}



sub freezer {
    my ($self, $out) = @_;

    # Check for out file:
    if (!$out) { croak MODULE . ' requires an output path.' }

    # Write out a Storable version of the coverage data structure. We will not
    # be saving '0' entries, just a snapshot of the object:
    use Storable;
    use Storable qw( nstore store_fd nstore_fd freeze thaw dclone );
    $out .= '.rc';
    nstore $self, $out;

    return $self;
}



sub _glue {
    my %arg = @_;

    # Validate arguments:
    if (!$arg{glue}) { croak MODULE . ' requires objects names for glue.' }

    # Glue fragments together only if all pass validation criteria. Create a
    # single reference coverage object to return to the user.
    use Storable;
    use Storable qw( nstore store_fd nstore_fd freeze thaw dclone );
    my (%fragment, $name_id);
    my $i = 0;

    # Collect info for evaluation:
    foreach my $object (@{$arg{glue}}) {
        $i++;
        my $restored_fragment   = retrieve( $object );
        $fragment{$i}->{name}   = $restored_fragment->name();
        $fragment{$i}->{start}  = $restored_fragment->start();
        $fragment{$i}->{stop}   = $restored_fragment->stop();
        $fragment{$i}->{object} = $restored_fragment;
        if ($i == 1) {
            # First-in gets to set validation name:
            $name_id = $restored_fragment->name();
        }
    }

    # FRAGMENT VALIDATION
    # Fragments cannot: 1) overlap start/stop positions; 2) have different
    # names; 3) contain gaps between fragments.
    $i = 0;
    map {$_ = 0} my ($previous_start, $previous_stop, $terminal_start, $terminal_stop);
    FRAGVAL:
    foreach my $frag_id (sort {$fragment{$a}->{start} <=> $fragment{$b}->{start}} keys %fragment) {
        $i++;
        if ($fragment{$frag_id}->{name} ne $name_id) {
            croak MODULE . ' requires all object names be equal for glue procedure.';
        }
        if ($i == 1) {
            # First fragment:
            ($previous_start, $previous_stop) = ($fragment{$frag_id}->{start}, $fragment{$frag_id}->{stop});
            $terminal_start = $fragment{$frag_id}->{start};
        }
        else {
            # Progressive fragment:
            if ($fragment{$frag_id}->{start} != ($previous_stop + 1)) {
                croak MODULE . ' cannot glue a fragment that overlaps or has a gap.';
            }
            else {
                if ($fragment{$frag_id}->{stop} > $terminal_stop) { $terminal_stop = $fragment{$frag_id}->{stop} }
                next FRAGVAL;
            }
        }
    }

    # All fragments passed FRAGVAL, so return a single glued object:
    my $myGluedRef = RefCov::Reference->new(
                                            name  => $name_id,
                                            start => $terminal_start,
                                            stop  => $terminal_stop,
                                           );

    # REQUIRED: Update the composite object to include the incoming
    # object's coverage information.
    foreach my $restore_id (sort {$fragment{$a}->{start} <=> $fragment{$b}->{start}} keys %fragment) {
        my $restored = $fragment{$restore_id}->{object};
        foreach my $position (keys %{$restored->{_ref_coverage}}) {
            $myGluedRef->_compose_depth(
                                        pos   => $position,
                                        depth => $restored->depth( pos => $position ),
                                       );
        }

        # OPTIONAL: Update the composite object to include layer names.
        # ------------------------------------------------------------------------
        if ($restored->_is_layer_names()) {
            foreach my $layer (keys %{$restored->{_layer_names}}) {
                $myGluedRef->{_layer_names}->{$layer} = $restored->{_layer_names}->{$layer};
            }
        }

        # OPTIONAL: Update the composite object to include base frequency.
        # ------------------------------------------------------------------------
        # First in gets to test for base frequency being present.
        if ($restored->{_base_frequency}->is_base_frequency()) {
            $myGluedRef->{_base_frequency}->compose( $restored->{_base_frequency} );
        }
    }

    return $myGluedRef;
}



sub _thaw_compose {
    my %arg = @_;

    my $storable_files = $arg{storable_files};
    # ------------------------------------------------------------------------
    # WE RETURN A COMPOSITE OBJECT TO SET IN THE CLASS CONSTRUCTOR!!!
    # ---------------------------------------------------------------
    # Take a list of Storable files (as created by method: freezer ), compose
    # them on top of one and other, return this object to the user. Each
    # Storable file that the user passes must have identical ref_name--or this
    # will fail. We need to compose: 1) coverage; 2) layer names; 3) base
    # frequency information.
    # ------------------------------------------------------------------------
    # NOTE:
    # For composition of base frequency and layer name information, we require
    # that _ALL_ incoming frozen objects have this information. Therefore, we
    # arbitrarily check the first object coming in to see if it has layer names
    # and base frequency information; if it does, we expect all others to have
    # the same information, and we attempt to compose this information.
    # ------------------------------------------------------------------------
    use Storable;
    use Storable qw( nstore store_fd nstore_fd freeze thaw dclone );
    my $composite_object;
    foreach my $file (@{$storable_files}) {
        if (!$composite_object) {
            # First in gets to name the composite object and be the root for
            # composition:
            $composite_object = retrieve( $file );
        }
        else {
            # Bail if the incoming ref_name is not the same as the root object:
            my $restored = retrieve( $file );
            if ($restored->name() ne $composite_object->name()) {
                croak MODULE . ' cannot compose files with different "name" values.';
            }

            # REQUIRED: Update the composite object to include the incoming
            # object's coverage information.
            foreach my $position (keys %{$restored->{_ref_coverage}}) {
                $composite_object->_compose_depth(
                                                  pos   => $position,
                                                  depth => $restored->depth( pos => $position ),
                                                 );
            }
            # Extend start-side if necessary:
            if ($restored->start() < $composite_object->start()) {
                $composite_object->{_start} = $restored->start();
            }
            # Extend stop-side if necessary:
            if ($restored->stop() > $composite_object->stop()) {
                $composite_object->{_stop} = $restored->stop();
            }

            # OPTIONAL: Update the composite object to include layer names.
            # ------------------------------------------------------------------------
            if ($restored->_is_layer_names()) {
                foreach my $layer (keys %{$restored->{_layer_names}}) {
                    $composite_object->{_layer_names}->{$layer} = $restored->{_layer_names}->{$layer};
                }
            }

            # OPTIONAL: Update the composite object to include base frequency.
            # ------------------------------------------------------------------------
            # First in gets to test for base frequency being present.
            if ($restored->{_base_frequency}->is_base_frequency()) {
                $composite_object->{_base_frequency}->compose( $restored->{_base_frequency} );
            }
        }

    }
    return $composite_object;
}



sub _compose_depth {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos})   { croak MODULE . ' requires a "pos" argument.'   }
    if (!$arg{depth}) { croak MODULE . ' requires a "depth" argument.' }

    if ($self->_is_covered( pos => $arg{pos} )) {
	$self->{_ref_coverage}->{$arg{pos}} = $self->{_ref_coverage}->{$arg{pos}} + $arg{depth}
    }
    else {
        $self->{_ref_coverage}->{$arg{pos}} = $arg{depth};
    }

    return $self;
}



sub _set_ranges {
    my $self = shift;

    # Set range pairs:
    map {$_ = 0} my ($is_collecting, $start, $stop, $i);
    POSITION:
    for ($self->start()..$self->stop()) {
        if ($self->_is_covered( pos => $_ )) {
            if ($is_collecting == 1) {
                unless ($_ == $self->stop()) {
                    next POSITION;
                }
                else {
                    $stop = $_;
                    $is_collecting = 0;
                }
            }
            else {
                $start = $_;
                $is_collecting = 1;
            }
        }
        else {
            if ($is_collecting == 1) {
                $stop = $_ - 1;
                $is_collecting = 0;
            }
            else {
                next POSITION;
            }
        }
        # Update collection hash:
        if ($start < $stop) {
            $i++;
            $self->{_ranges}->{$i}->{start} = $start;
            $self->{_ranges}->{$i}->{stop}  = $stop;
        }
    }

    return $self;
}



sub number_covered {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop} ) { croak MODULE . ' requires a "stop" argument.'  }

    # Return an array of the span bit coverage.
    my $count = 0;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_covered( pos => $_ )) {
	    $count++;
	}
    }
    return $count;
}



sub bit {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{pos}) { croak MODULE . ' requires a "pos" argument.' }

    my $bit = ($self->_is_covered( pos => $arg{pos} )) ? 1 : 0;

    return $bit;
}



sub span_bits {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop} ) { croak MODULE . '  requires a "stop" argument.'  }

    # Return an array of the span bit coverage.
    my @span_bits;
    for ($arg{start}..$arg{stop}) {
        if ($self->_is_covered( pos => $_ )) {
            push (@span_bits, '1');
	}
	else {
	    push (@span_bits, '0');
	}
    }
    return \@span_bits;
}



sub layer_names {
    my $self = shift;

    # Required arguments:
    unless ($self->_is_layer_names()) { croak MODULE . ' called null layer names; perhaps you forgot to pass "layer_name" in layer_read() method?' }

    # Return an array of the layer names, making them unique in the process:
    my (@layer_names, %name);
    foreach my $layer (sort keys %{$self->{_layer_names}}) {
	push (@layer_names, $layer);
    }

    return \@layer_names;
}



sub layer_names_span {
    my ($self, %arg) = @_;

    # Required arguments:
    if (!$arg{start}) { croak MODULE . ' requires a "start" argument.' }
    if (!$arg{stop} ) { croak MODULE . ' requires a "stop" argument.'  }
    unless ($self->_is_layer_names()) { croak MODULE . ' called null layer names; perhaps you forgot to pass "layer_name" in layer_read() method?' }

    # Return an array of the layer names SUBSET, making them unique in the
    # process:
    my (@layer_names, %name);
    foreach my $layer (sort keys %{$self->{_layer_names}}) {
        my $layer_start = $self->{_layer_names}->{$layer}->[0];
        my $layer_stop  = $self->{_layer_names}->{$layer}->[1];
        my $add_layer   = FALSE;
        if (
            ($layer_start >= $arg{start}) &&
            ($layer_stop <= $arg{stop}  )
           ) {
            # Subsumed:
            $add_layer = TRUE;
        }
        elsif (
               ($layer_start < $arg{start})  &&
               (($layer_stop >= $arg{start}) && ($layer_stop <= $arg{stop}))
              ) {
            $add_layer = TRUE;
        }
        elsif (
               ($layer_start >= $arg{start} && ($layer_start <= $arg{stop})) &&
               (($layer_stop > $arg{stop}))
              ) {
            $add_layer = TRUE;
        }
        elsif (
               ($layer_start < $arg{start}) &&
               ($layer_stop > $arg{stop})
              ) {
            $add_layer = TRUE;
        }
        elsif (
               ($layer_start < $arg{start}) &&
               ($layer_stop < $arg{start})
              ) {
            # Out of bounds downstream:
            $add_layer = FALSE;
        }
        elsif (
               ($layer_start > $arg{stop}) &&
               ($layer_stop > $arg{stop})
              ) {
            # Out of bounds upstream:
            $add_layer = FALSE;
        }
        else {
            $add_layer = FALSE;
        }

        if ($add_layer eq TRUE) { push (@layer_names, $layer) }
    }

    return \@layer_names;
}



sub range_index {
    my $self = shift;

    # Build range index in the object and return a hashref:
    $self->_set_ranges();

    return $self->{_ranges};
}



sub print_ranges {
    my $self = shift;

    # Print a tab-delimited version of the ranges:
    unless( $self->{_ranges} ) { $self->_set_ranges() }  # lazy load
    foreach my $span (sort {$a <=> $b} keys %{$self->{_ranges}}) {
        print join (
                    "\t",
                    $self->name(),
                    $self->{_ranges}->{$span}->{start}, # $self->range_start( $id )
                    $self->{_ranges}->{$span}->{stop},  # $self->range_stop(  $id )
                   ), "\n";
    }

    return $self;
}



sub print_gaps {
    my $self = shift;

    unless($self->{_ranges}) { $self->_set_ranges() }  # lazy load
    my $end = scalar keys %{$self->{_ranges}};
    my $last_right;

    # Analyze gap space:
    foreach my $span (sort {$a <=> $b} keys %{$self->{_ranges}}) {
	my ($left, $right) = ($self->{_ranges}->{$span}->{start}, $self->{_ranges}->{$span}->{stop});
	my ($gap_left, $gap_right);

	# First range may be a gap:
	if ($span == 1) {
	    if ($self->{_ranges}->{1}->{start} != 1) {
		$gap_left   = 1;
		$gap_right  = $left - 1;
		$last_right = $right;
	    }
	    else {
		$last_right = $right;
		next;
	    }
	}
	else {
	    $gap_left   = $last_right + 1;
	    $gap_right  = $left       - 1;
	    $last_right = $right;
	}

	# Print gap range:
        print join (
                    "\t",
		    'GAP',
                    $self->name(),
		    $gap_left,
		    $gap_right,
		    ), "\n";

	# Terminal extension:
	if ($span == $end) {
	    if ($self->{_ranges}->{$end}->{stop} != $self->reflen()) {
		$gap_left  = $right + 1;
		$gap_right = $self->reflen();
		print join (
			    "\t",
			    'GAP',
			    $self->name(),
			    $gap_left,
			    $gap_right,
			    ), "\n";
	    }
	}
    }

    return $self;
}



sub depth_bins {
    my $self = shift;

    # Return an array reference of depth bins in order:
    my (%bins, @bins);
    my $last = 0;
    for ($self->start()..$self->stop()) {
        if ($self->_is_covered( pos => $_ )) {
	    $bins{ $self->depth( pos => $_ ) }++;
	    $last = $self->depth( pos => $_ ) if ($self->depth( pos => $_ ) > $last);
        }
        else {
	    $bins{0}++;
        }
    }

    # Fill in empty bins up to the end of the range:
    for (0..$last) {
	if ($bins{$_}) {
	    push (@bins, "$_\t$bins{$_}");
	}
	else {
	    push (@bins, "$_\t0");
	}
    }

    return \@bins;
}



sub save_depth_bins_file {
    my ($self, $out) = @_;

    # Check for out file:
    if (!$out) { croak MODULE . ' requires an output path.' }

    # Write a tab-delimited file for the depth bins. This is the total
    # length of the footprint, position-by-position broken into bins of
    # depth of coverage:
    my $bins_file = IO::File->new( ">$out" ) or croak MODULE . ' could not save depth bins file.';
    foreach my $bin (@{$self->depth_bins()}) {
	print $bins_file "$bin\n";
    }
    $bins_file->close();

    return $self;
}



sub print_depth_bins {
    my $self = shift;

    # Write a tab-delimited file for the depth bins. This is the total
    # length of the footprint, position-by-position broken into bins of
    # depth of coverage:
    foreach my $bin (@{$self->depth_bins()}) {
	print "$bin\n";
    }

    return $self;
}



sub save_topology_file {
    my ($self, $out) = @_;

    # Check for out file:
    if (!$out) { croak MODULE . ' requires an output path.' }

    # Write a tab-delimited, 2 column file of coordinates (position:depth). This
    # file is useful for plotting the coverage topology across the length of the
    # reference footprint.
    my $topology_file = IO::File->new( ">$out" ) or croak MODULE . ' could not save coverage topology file.';
    my $pos = $self->start();
    foreach my $depth (@{$self->depth_span(
                                           start => $self->start(),
                                           stop =>  $self->stop(),
                                          )}
                      ) {
        print $topology_file "$pos\t$depth\n";
        $pos++;
    }
    $topology_file->close();

    return $self;
}



sub save_base_frequency_topology_file {
    my ($self, $out) = @_;

    # Check for out file:
    if (!$out) { croak MODULE . ' requires an output file path.' }

    # Write a tab-delimited, 7 column file of coordinates
    # (pos:A:C:G:T:N:-). This output is useful for plotting the coverage
    # topology across the length of the reference footprint.
    my $topology_file = IO::File->new( ">$out" ) or croak MODULE . ' could not save coverage topology file.';
    for ($self->start()..$self->stop()) {
        print $topology_file join (
                                   "\t",
                                   $_,
                                   @{$self->{_base_frequency}->base_frequency( pos => $_ )},
                                  ) . "\n";
    }
    $topology_file->close();

    return $self;
}



sub print_base_heterozygosity_topology {
    my ($self, %arg) = @_;

    # Write a tab-delimited, 5 column file of: 1) ref position; 2) depth of
    # coverage at ref position; 3) top 2 allele calls; 4) ratio of alleles
    # called; 5) ratio of allelles callled (percent form).
    for ($self->start()..$self->stop()) {
        my $consensus = $self->{_base_frequency}->base_heterozygosity_consensus(
                                                                                pos       => $_,
                                                                                min_depth => $arg{min_depth},
                                                                                min_ratio => $arg{min_ratio},
                                                                               );
        if ($consensus) {
            print join (
                        "\t",
                        $_,
                        split ('\|', $consensus),
                       ) . "\n";
        }
        else {
            if (defined $arg{pad}) { print $_ . "\n" }
        }
    }

    return $self;
}



sub print_base_frequency_topology {
    my $self = shift;

    # Write a tab-delimited, 7 column file of coordinates
    # (pos:A:C:G:T:N:-). This output is useful for plotting the coverage
    # topology across the length of the reference footprint.
    for ($self->start()..$self->stop()) {
        print join (
                    "\t",
                    $_,
                    @{$self->{_base_frequency}->base_frequency( pos => $_ )},
                   ) . "\n";
    }

    return $self;
}



sub print_topology {
    my $self = shift;

    # Write a tab-delimited, 2 column file of coordinates (position:depth). This
    # output is useful for plotting the coverage topology across the length of
    # the reference footprint.
    my $pos = $self->start();
    foreach my $depth (@{$self->depth_span(
                                           start => $self->start(),
                                           stop =>  $self->stop(),
                                          )}
                      ) {
        print "$pos\t$depth\n";
        $pos++;
    }

    return $self;
}



sub print_ranges_YAML {
    my $self = shift;

    # Print a YAML document of ranges/members:
    unless($self->{_ranges}) { $self->_set_ranges() }  # lazy load

    # YAML header:
    print "---\n";
    print "REF: "       . $self->name()  . "\n";
    print "REF START: " . $self->start() . "\n";
    print "REF STOP: "  . $self->stop()  . "\n";
    print "RANGES:\n";

    my $range_i    = 0;
    my $range_last = scalar keys %{$self->{_ranges}};
    foreach my $span (sort {$a <=> $b} keys %{$self->{_ranges}}) {
	$range_i++;
	print "\n";
	print "  # (range $range_i/$range_last)\n";
	print "  $range_i:\n";

	# Required arguments:
        unless ($self->_is_layer_names()) { croak MODULE . ' called null layer names; perhaps you forgot to pass "layer_name" in layer_read() method?' }
	print "    START: " . $self->{_ranges}->{$span}->{start} . "\n";
	print "    STOP: "  . $self->{_ranges}->{$span}->{stop}  . "\n";
	print "    LENGTH: " . (($self->{_ranges}->{$span}->{stop} - $self->{_ranges}->{$span}->{start}) + 1) . "\n";
	print "    MEMBERS:\n";

	# Membership evaluation of reads:
	my $membership = {};
	foreach my $query (sort keys %{$self->{_layer_names}}) {
	    if (
		$self->{_layer_names}->{$query}[0] >= $self->{_ranges}->{$span}->{start} &&
		$self->{_layer_names}->{$query}[1] <= $self->{_ranges}->{$span}->{stop}
		) {
		$membership->{$query}->{start}  = $self->{_layer_names}->{$query}[0];
		$membership->{$query}->{stop}   = $self->{_layer_names}->{$query}[1];
		$membership->{$query}->{length} = ($self->{_layer_names}->{$query}[1] - $self->{_layer_names}->{$query}[0]) + 1;
	    }
	}
	my $member_i = 0;
	foreach my $member (sort {$membership->{$b}->{length} <=> $membership->{$a}->{length}} keys %{$membership}) {
	    $member_i++;
	    print "        $member_i:\n";
	    print "          NAME: "    . $member                          . "\n";
	    print "          LENGTH: "  . $membership->{$member}->{length} . "\n";
	    print "          START: "   . $membership->{$member}->{start}  . "\n";
	    print "          STOP: "    . $membership->{$member}->{stop}   . "\n";
	}
    }
    print "...\n";  # end of YAML document

    return $self;
}



sub print_stats {
    my ($self, %arg) = @_;

    my $print_tags = FALSE;
    if (defined $arg{tags}) { $print_tags = TRUE }

    # Was min_depth passed?
    my $min_depth = 0;
    if ($arg{min_depth}) { $min_depth = $arg{min_depth} }

    # Gather statistics.
    my (
        $percent_ref_cov,
        $total_ref_bases,
        $total_cov_bases,
        $missing_ref_bases,
        $ave_cov_depth,
        $stdev_cov_depth,
        $med_cov_depth,
        $gaps,
        $ave_gap_length,
        $stdev_ave_gap_length,
        $med_gap_length,
        $min_depth_filter,
        $discarded_bases,
        $max_unique_filter,
        $total_reads_layered,
        $total_unique_start_sites,
        $percent_redundancy_of_layers,
       ) = @{$self->generate_stats( min_depth => $min_depth )};

    # Print general YAML format report.
    if ($print_tags == TRUE ) { print "---\n" }
    print $self->name() . ":\n";
    print q/ / . "Percent of Reference Bases Covered: "              . $percent_ref_cov              . "\n";
    print q/ / . "Total Number of Reference Bases: "                 . $total_ref_bases              . "\n";
    print q/ / . "Total Number of Covered Bases: "                   . $total_cov_bases              . "\n";
    print q/ / . "Number of Missing Bases: "                         . $missing_ref_bases            . "\n";
    print q/ / . "Average Coverage Depth: "                          . $ave_cov_depth                . "\n";
    print q/ / . "Standard Deviation Average Coverage Depth: "       . $stdev_cov_depth              . "\n";
    print q/ / . "Median Coverage Depth: "                           . $med_cov_depth                . "\n";
    print q/ / . "Number of Gaps: "                                  . $gaps                         . "\n";
    print q/ / . "Average Gap Length: "                              . $ave_gap_length               . "\n";
    print q/ / . "Standard Deviation Average Gap Length: "           . $stdev_ave_gap_length         . "\n";
    print q/ / . "Median Gap Length: "                               . $med_gap_length               . "\n";
    print q/ / . "Min. Depth Filter: "                               . $min_depth_filter             . "\n";
    print q/ / . "Discarded Bases (Min. Depth Filter): "             . $discarded_bases              . "\n";
    print q/ / . "Max. Unique Filter: "                              . $max_unique_filter            . "\n";
    print q/ / . "Total Number of Reads Layered: "                   . $total_reads_layered          . "\n";
    print q/ / . "Total Number of Unique Start Site Reads Layered: " . $total_unique_start_sites     . "\n";
    print q/ / . "Percent Redundancy of Read Layers: "               . $percent_redundancy_of_layers . "\n";
    if ($print_tags == TRUE) { print "...\n" }

    return $self;
}



1;  # end of package


__END__


=head1 NAME

RefCov::Reference - [One line description of module's purpose here]


=head1 VERSION

This document describes RefCov::Reference version 0.0.1


=head1 SYNOPSIS

    use RefCov::Reference;

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

RefCov::Reference requires no configuration files or environment variables.


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
C<bug-refcov-reference@rt.cpan.org>, or through the web interface at
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
