package Genome::Model::AmpliconAssembly::Report::AssemblyStats;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

class Genome::Model::AmpliconAssembly::Report::AssemblyStats {
    is => 'UR::Object',
    #is => 'Genome::Model::Report',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    $self->{_metrix} = {
        sequence_srcs => {
            assembly => 0,
            read => 0,
            none => 0,
        },
        has_one_valid_read => 0,
        #length => 0,
        lengths => [],
        qual => 0,
        qual_gt_20 => 0,
        reads => [],
        reads_assembled => [],
    };

    return $self;
}

sub add_amplicon {
    my ($self, $amplicon) = @_;
    
    $self->{_metrix}->{sequence_srcs}->{ $amplicon->get_bioseq_source }++;

    return 1 unless $amplicon->was_assembled_successfully;

    # Length
    my $bioseq = $amplicon->get_bioseq;
    # $self->{_metrix}->{length} += $bioseq->length;
    push @{ $self->{_metrix}->{lengths} }, $bioseq->length;

    # Get quals
    for my $qual ( @{$bioseq->qual} ) { 
        $self->{_metrix}->{qual} += $qual;
        $self->{_metrix}->{qual_gt_20}++ if $qual >= 20;
    }

    # Reads
    push @{ $self->{_metrix}->{reads} }, $amplicon->get_read_count;
    push @{ $self->{_metrix}->{reads_assembled} }, $amplicon->get_assembled_read_count;

    return 1;
}

sub is_generated {
    return;
}

sub generate {
    my ($self, $build) = @_;
}

sub output_csv {
    my $self = shift;

    my %totals = $self->calculate_totals
        or return;

    print( join(',', sort { $a cmp $b } keys %totals) );
    print("\n");
    print( join(',', map { $totals{$_} } sort { $a cmp $b } keys %totals) );
    print("\n");

    return 1;
}

sub calculate_totals {
    my $self = shift;

    my $sum = sub{
        my $total = 0;
        for ( @_ ) { $total += $_; }
        return $total;
    };

    my $attempted = $sum->( values %{$self->{_metrix}->{sequence_srcs}} );

    confess ref($self)." ERROR: Cannot calculate totals because no amplicons added" unless $attempted;
    
    my $assembled = $self->{_metrix}->{sequence_srcs}->{assembly};
    my $read_cnt = $sum->( @{$self->{_metrix}->{reads}} );
    my $assembled_read_cnt = $sum->( @{$self->{_metrix}->{reads_assembled}} );
    my @lengths = sort { $a <=> $b } @{ $self->{_metrix}->{lengths} };
    my $length = $sum->(@lengths);
    my @reads = sort { $a <=> $b } @{ $self->{_metrix}->{reads_assembled} };
    my %read_cnts;
    for my $cnt ( @reads ) {
        $read_cnts{ sprintf('assemblies_with_%s_reads', $cnt) }++;
    }

    my %totals = (
        map( { 'src_is_'.$_ => $self->{_metrix}->{sequence_srcs}->{$_} } keys %{$self->{_metrix}->{sequence_srcs}}),
        assembled => $assembled,
        attempted => $attempted,
        assembled_pct => sprintf(
            '%.2f', 
            100 * $assembled / $attempted,
        ),
        reads => $read_cnt,
        reads_assembled => $assembled_read_cnt,
        reads_assembled_pct => sprintf(
            '%.2f',
            100 * $assembled_read_cnt / $read_cnt,
        ),
        length_min => $lengths[0],
        length_max => $lengths[$#lengths],
        length_median => $lengths[( $#lengths / 2 )],
        length_avg => sprintf(
            '%.0f',
            $length / $assembled,
        ),
        qual_avg => sprintf(
            '%.2f', 
            $self->{_metrix}->{qual} / $length,
        ),
        greater_than_qual20_per_assembly => sprintf(
            '%.2f',
            $self->{_metrix}->{qual_gt_20} / $assembled,
        ),
        reads_assembled_min => $reads[0],
        reads_assembled_max => $reads[$#reads],
        reads_assembled_median => $reads[( $#reads / 2 )],
        reads_assembled_avg_per_assembly => sprintf(
            '%.2F',
            $assembled_read_cnt / $assembled,
        ),
        %read_cnts,
    );

    return %totals;
}

1;

#$HeadURL$
#$Id$
