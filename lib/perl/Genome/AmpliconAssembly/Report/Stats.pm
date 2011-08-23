package Genome::AmpliconAssembly::Report::Stats;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::AmpliconAssembly::Report::Stats {
    is => 'Genome::AmpliconAssembly::Report',
    has => [
    _amplicon_size => {
        is => 'Integer',
        doc => 'Expected amplicon size.',
    },
    ],
};

#< Generator >#
sub description {
    return 'Assembly and Quality Stats for an Amplicon Assembly';
}

sub _add_to_report_xml {
    my $self = shift;

    $self->_validate_amplicon_size 
        or return;

    $self->_create_metrics;

    # Add AAs 
    for my $amplicon_assembly ( @{$self->amplicon_assemblies} ) {
        my $amplicons = $amplicon_assembly->get_amplicons;
        unless ( $amplicons ) {
            $self->error_message("No amplicons in directory: ", $amplicon_assembly->directory);
            return;
        }
        for my $amplicon ( @$amplicons ) {
            $self->_add_amplicon($amplicon)
                or return;
        }
    }

    # Assembly Stats 
    my $assembly_stats = $self->get_assembly_stats
        or return;
    $self->_add_dataset(
        name => 'stats',
        row_name => 'stat',
        headers => $assembly_stats->{headers},
        rows => [ $assembly_stats->{stats} ],
    ) or return;

    # Postion Quality
    my $position_quality_stats = $self->get_position_quality_stats
        or return;
    for my $read_count ( sort { $a <=> $b } keys %{$position_quality_stats->{position_qualities}} ) {
        $self->_add_dataset(
            name => 'qualities',
            label => 'read-count-'.$read_count,
            'length' => $self->_amplicon_size,
            row_name => 'quality',
            headers => $position_quality_stats->{headers},
            rows => $position_quality_stats->{position_qualities}->{$read_count},
        );
    }

    return 1;
}

#< Amplicon Size >#
sub _validate_amplicon_size {
    my $self = shift;

    my $amplicon_size = $self->amplicon_assemblies->[0]->assembly_size;
    unless ( $amplicon_size ) {
        $self->error_message("No assembly size found for amplicon assembly: ".$self->amplicon_assemblies->[0]->directory);
        $self->delete;
        return;
    }
    
    for my $amplicon_assembly ( @{$self->amplicon_assemblies} ) {
        next if $amplicon_assembly->assembly_size eq $amplicon_size;
        $self->error_message("Amplicon assemblies assembly sizes are not equal.");
        $self->delete;
        return;
    }

    return $self->_amplicon_size($amplicon_size);
}


#< Metrics, etc >#
sub _create_metrics {
    my $self = shift;

    $self->{_metrix} = {
        # stats
        assembled => 0,
        attempted => 0,
        lengths => [],
        qual => 0,
        qual_gt_20 => 0,
        reads => [],
        reads_assembled => [],
        zeros => 0,
        #read_seq_not_in_consensus => [],
        # qual
        qual_by_pos => {},
    };

    return 1;
}

sub _add_amplicon {
    my ($self, $amplicon) = @_;

    $self->{_metrix}->{attempted}++;

    return 1 unless $amplicon->was_assembled_successfully;

    $self->{_metrix}->{assembled}++;

    my $bioseq = $amplicon->get_bioseq;
    unless( $bioseq ) { # very bad
        $self->error_message('Amplicon '.$amplicon->get_name.' was assembled succeszsfully, but counld not get bioseq.');
        return;
    }

    $self->_add_stats_for_consensus($amplicon, $bioseq)
        or return;

    $self->_add_stats_for_reads($amplicon, $bioseq)
        or return;

    return 1;
}

sub _add_stats_for_consensus {
    my ($self, $amplicon, $bioseq) = @_;

    # Length
    push @{$self->{_metrix}->{lengths}}, $bioseq->length;

    # Get quals
    for my $qual ( @{$bioseq->qual} ) { 
        $self->{_metrix}->{qual} += $qual;
        $self->{_metrix}->{qual_gt_20}++ if $qual >= 20;
    }

    # Zeros
    if ( $bioseq->qual_text =~ /^0 / or $bioseq->qual_text =~ / 0$/ ) {
        $self->{_metrix}->{zeros}++;
    }

    return 1;
}

sub _add_stats_for_reads {
    my ($self, $amplicon, $bioseq) = @_;

    push @{ $self->{_metrix}->{reads} }, $amplicon->get_read_count;
    my $read_count = $amplicon->get_assembled_read_count;
    push @{ $self->{_metrix}->{reads_assembled} }, $read_count;

    return 1 unless $amplicon->is_bioseq_oriented;
    
    my $i = 1;
    my $last_qual_pos = @{$bioseq->qual} - 1;
    if ( $last_qual_pos < $self->_amplicon_size ) { # not enough quals, need to move start
        $i = $self->_amplicon_size - $last_qual_pos - 1;
    }

    my $qual_total = 0;
    my $qual20_bases = 0;
    $self->{_metrix}->{qual_by_pos}->{$read_count} = [] unless exists $self->{_metrix}->{qual_by_pos}->{$read_count};
    for my $qual ( @{$bioseq->qual} ) { 
        $qual_total += $qual;
        $qual20_bases++ if $qual >= 20;
        $self->{_metrix}->{qual_by_pos}->{$read_count}->[$i++] += $qual;
    }

    return 1;
}

sub get_assembly_stats {
    my $self = shift;

    my $attempted = $self->{_metrix}->{attempted};
    unless ( $attempted ) {
        $self->error_message("Cannot calculate totals because no amplicons added.");
        return;
    }

    my $assembled = $self->{_metrix}->{assembled};
    unless ( $assembled ) {
        $self->warning_message("No amplicons assembled.");
        return {
            headers => [qw/ assembled attempted assembly-success /],
            stats => [ $assembled, $attempted, sprintf('%.2f', (100 * $assembled / $attempted)) ] 
        };
    }

    my $sum = sub{
        my $total = 0;
        for ( @_ ) { $total += $_; }
        return $total;
    };

    my $read_cnt = $sum->( @{$self->{_metrix}->{reads}} );
    my $assembled_read_cnt = $sum->( @{$self->{_metrix}->{reads_assembled}} );
    my @lengths = sort { $a <=> $b } @{ $self->{_metrix}->{lengths} };
    my $length = $sum->(@lengths);
    my @reads = sort { $a <=> $b } @{ $self->{_metrix}->{reads_assembled} };
    my %read_cnts;
    for my $cnt ( @reads ) {
        $read_cnts{ sprintf('assemblies-with-%s-reads', $cnt) }++;
    }

    my %totals = (
        assembled => $assembled,
        attempted => $attempted,
        'assembly-success' => sprintf(
            '%.2f', 
            100 * $assembled / $attempted,
        ),
        'assemblies-with-zeros' => $self->{_metrix}->{zeros},
        #assemblies_where_read_seq_does_not_match_consensus => scalar(@{$self->{_metrix}->{read_seq_not_in_consensus}}),
        'length-minimum' => $lengths[0],
        'length-maximum' => $lengths[$#lengths],
        'length-median' => $lengths[( $#lengths / 2 )],
        'length-average' => sprintf(
            '%.0f',
            $length / $assembled,
        ),
        'quality-base-average' => sprintf(
            '%.2f', 
            $self->{_metrix}->{qual} / $length,
        ),
        'quality-less-than-20-bases-per-assembly' => sprintf(
            '%.2f',
            $self->{_metrix}->{qual_gt_20} / $assembled,
        ),
        reads => $read_cnt,
        'reads-assembled' => $assembled_read_cnt,
        'reads-assembled-success' => sprintf(
            '%.2f',
            100 * $assembled_read_cnt / $read_cnt,
        ),
        'reads-assembled-minimum' => $reads[0],
        'reads-assembled-maximum' => $reads[$#reads],
        'reads-assembled-median' => $reads[( $#reads / 2 )],
        'reads-assembled-average' => sprintf(
            '%.2F',
            $assembled_read_cnt / $assembled,
        ),
        %read_cnts,
    );

    return {
        headers => [ sort { $a cmp $b } keys %totals ],
        stats => [ map { $totals{$_} } sort { $a cmp $b } keys %totals ],
    }
}

sub get_position_quality_stats {
    my $self = shift;

    my %read_counts;
    for my $read_count ( @{$self->{_metrix}->{reads_assembled}} ) {
        $read_counts{$read_count}++;
    }
    
    my %position_qualities;
    for my $read_count ( sort { $a <=> $b } keys %read_counts ) {
        my $pos = 0;
        $position_qualities{$read_count} = [
        map { 
            [ ++$pos, sprintf('%.0f', ($_ || 0) / $read_counts{$read_count}) ]
        } @{$self->{_metrix}->{qual_by_pos}->{$read_count}}
        ],
    }

    return {
        headers => [qw/ position value /],
        position_qualities => \%position_qualities,
    };
}

1;

#$HeadURL$
#$Id$
