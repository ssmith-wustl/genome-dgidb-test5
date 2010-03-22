package Genome::Model::MetagenomicComposition16s::Report::Summary;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::MetagenomicComposition16s::Report::Summary {
    is => 'Genome::Model::MetagenomicComposition16s::Report',
};

#< Generator >#
sub description {
    return 'Summary Report for '.
    Genome::Utility::Text::capitalize_words( $_[0]->build->description );
}

sub _add_to_report_xml {
    my $self = shift;

    my $build = $self->build;
    unless ( $self->build->amplicons_attempted ) {
        $self->error_message("No amplicons attempted for ".$build->description);
        return;
    }
    
    $self->_create_metrics;

    my $amplicons = $self->build->amplicon_sets
        or return;

    while ( my $amplicon = $amplicons->() ) {
        $self->_add_amplicon($amplicon);
    }

    # Summary Stats 
    my $summary_stats = $self->get_summary_stats
        or return;
    $self->_add_dataset(
        name => 'stats',
        row_name => 'stat',
        headers => $summary_stats->{headers},
        rows => [ $summary_stats->{stats} ],
    ) or return;

    return 1;
}

sub _create_metrics {
    my $self = shift;

    $self->{_metrix} = {
        lengths => [],
        reads => [],
        reads_assembled => [],
        zeros => 0,
    };

    return 1;
}

sub _add_amplicon {
    my ($self, $amplicon) = @_;

    # Bioseq
    my $bioseq = $amplicon->oriented_bioseq
        or return 1; # ok - bioseq only returned if assembled and oriented

    # Length
    push @{$self->{_metrix}->{lengths}}, $bioseq->length;

    # Zeros
    if ( $bioseq->qual_text =~ /^0 / or $bioseq->qual_text =~ / 0$/ ) {
        $self->{_metrix}->{zeros}++;
    }

    # Reads
    push @{ $self->{_metrix}->{reads} }, $amplicon->read_count;
    my $read_count = $amplicon->assembled_read_count;
    push @{ $self->{_metrix}->{reads_assembled} }, $read_count;

    return 1;
}

sub get_summary_stats {
    my $self = shift;

    my $build = $self->build;
    my $attempted = $build->amplicons_attempted;
    my $processed = $build->amplicons_processed;
    unless ( $processed ) {
        $self->warning_message("No amplicons processed for ".$build->description);
        return {
            headers => [qw/ amplicons-processed amplicons-attempted amplicons-success /],
            stats => [ $processed, $attempted, sprintf('%.2f', (100 * $processed / $attempted)) ] 
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

    my %totals = (
        # Amplicons
        'amplicons-attempted' => $attempted,
        'amplicons-processed' => $processed,
        'amplicons-processed-success' => $build->amplicons_processed_success,
        'amplicons-classified' => $build->amplicons_classified,
        'amplicons-classified-success' => $build->amplicons_classified,
        'amplicons-with-zeros' => $self->{_metrix}->{zeros},
        # Lengths
        'length-minimum' => $lengths[0],
        'length-maximum' => $lengths[$#lengths],
        'length-median' => $lengths[( $#lengths / 2 )],
        'length-average' => sprintf(
            '%.0f',
            $length / $processed,
        ),
        # Reads
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
            $assembled_read_cnt / $processed,
        ),
    );

    return {
        headers => [ sort { $a cmp $b } keys %totals ],
        stats => [ map { $totals{$_} } sort { $a cmp $b } keys %totals ],
    }
}

1;

#$HeadURL$
#$Id$
