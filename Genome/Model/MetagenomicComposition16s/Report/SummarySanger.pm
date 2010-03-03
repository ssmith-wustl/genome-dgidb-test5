package Genome::Model::MetagenomicComposition16s::Report::SummarySanger;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::MetagenomicComposition16s::Report::SummarySanger {
    is => 'Genome::Model::MetagenomicComposition16s::Report',
};

#< Generator >#
sub description {
    my $self = shift;

    return sprintf(
        'Metagenomic Composition Summary Report for Model\'s (<%s> <%s>) Build <%s>)',
        $self->model_name,
        $self->model_id,
        $self->build_id,
    );
}

sub _add_to_report_xml {
    my $self = shift;

    unless ( $self->build->length_of_16s_region ) {
        $self->error_message('No amplicon size for build ('.$self->build_id.').');
        return;
    }

    $self->_create_metrics;

    my $amplicons = $self->build->amplicon_iterator
        or return;

    while ( my $amplicon = $amplicons->() ) {
        $self->_add_amplicon($amplicon);
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
        next unless @{$position_quality_stats->{position_qualities}->{$read_count}};
        $self->_add_dataset(
            name => 'qualities',
            label => 'read-count-'.$read_count,
            'length' => $self->build->length_of_16s_region,
            row_name => 'quality',
            headers => $position_quality_stats->{headers},
            rows => $position_quality_stats->{position_qualities}->{$read_count},
        );
    }

    return 1;
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

    my $bioseq = $amplicon->oriented_bioseq
        or return 1; # ok - bioseq only returned if assembled and oriented

    $self->{_metrix}->{assembled}++;

    $self->_add_stats_for_consensus($amplicon, $bioseq);
    $self->_add_stats_for_reads($amplicon, $bioseq);

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

    push @{ $self->{_metrix}->{reads} }, $amplicon->read_count;
    my $read_count = $amplicon->assembled_read_count;
    push @{ $self->{_metrix}->{reads_assembled} }, $read_count;

    my $i = 1;
    my $last_qual_pos = @{$bioseq->qual} - 1;
    my $length_of_16s_region = $self->build->length_of_16s_region;
    if ( $last_qual_pos < $length_of_16s_region ) { # not enough quals, need to move start
        $i = $length_of_16s_region - $last_qual_pos - 1;
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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/AmpliconAssembly/Report/Stats.pm $
#$Id: Stats.pm 53411 2009-11-30 19:10:18Z ebelter $
