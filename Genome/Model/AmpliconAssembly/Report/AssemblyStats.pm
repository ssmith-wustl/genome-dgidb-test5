package Genome::Model::AmpliconAssembly::Report::AssemblyStats;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::AmpliconAssembly::Report::AssemblyStats {
    is => 'Genome::Model::AmpliconAssembly::Report',
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

sub _generate_data {
    my $self = shift;

    for my $build ( $self->builds ) {
        my $amplicons = $build->get_amplicons;
        unless ( $amplicons ) {
            $self->error_message( sprintf("No amplicons for build (ID %s)", $build->id) );
            return;
        }
        for my $amplicon ( @$amplicons ) {
            $self->add_amplicon($amplicon)
                or return;
        }
    }

    my %totals = $self->_calculate_totals
        or return;

    my @headers = sort { $a cmp $b } keys %totals;
    #my @headers = map { join(' ', map { ucfirst } split('_', $_)) } sort { $a cmp $b } keys %totals;
    my @data = map { $totals{$_} } sort { $a cmp $b } keys %totals; # only one row

    my $description = sprintf(
        'Assembly stats for amplicon assembly build(s) (%s)',
        join(',', $self->build_ids),
    );

    my $csv = $self->_generate_csv_string(
        headers => \@headers,
        data => [ \@data ],
    )
        or return;

    my $html = $self->_generate_vertical_html_table(
        title => $description,
        table_attrs => 'style="text-align:left;border:groove;border-width:3"',
        horizontal_headers => \@headers,
        data => [ \@data ],
        entry_attrs => 'style="border:groove;border-width:1"',
    )
        or return;

    return {
        description => $description,
        csv => $csv,
        html => '<html>'.$html.'</html>',
    };
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

sub _calculate_totals {
    my $self = shift;

    my $sum = sub{
        my $total = 0;
        for ( @_ ) { $total += $_; }
        return $total;
    };

    my $attempted = $sum->( values %{$self->{_metrix}->{sequence_srcs}} );

    unless ( $attempted ) {
        $self->error_message("Cannot calculate totals because no amplicons added");
        return;
    }

    my $assembled = $self->{_metrix}->{sequence_srcs}->{assembly};
    my $read_cnt = $sum->( @{$self->{_metrix}->{reads}} );
    my $assembled_read_cnt = $sum->( @{$self->{_metrix}->{reads_assembled}} );
    my @lengths = sort { $a <=> $b } @{ $self->{_metrix}->{lengths} };
    my $length = $sum->(@lengths);
    my @reads = sort { $a <=> $b } @{ $self->{_metrix}->{reads_assembled} };
    my %read_cnts;
    for my $cnt ( @reads ) {
        $read_cnts{ sprintf('Assemblies with %s Reads', $cnt) }++;
    }

    my %totals = (
        map( { 'Sequence Source is '.ucfirst($_) => $self->{_metrix}->{sequence_srcs}->{$_} } keys %{$self->{_metrix}->{sequence_srcs}}),
        Assembled => $assembled,
        Attempted => $attempted,
        'Assembly Success' => sprintf(
            '%.2f', 
            100 * $assembled / $attempted,
        ),
        'Length Minimum' => $lengths[0],
        'Length Maximum' => $lengths[$#lengths],
        'Length Median' => $lengths[( $#lengths / 2 )],
        'Length Average' => sprintf(
            '%.0f',
            $length / $assembled,
        ),
        'Quality Base Average' => sprintf(
            '%.2f', 
            $self->{_metrix}->{qual} / $length,
        ),
        'Quality >= 20 Bases per Assembly' => sprintf(
            '%.2f',
            $self->{_metrix}->{qual_gt_20} / $assembled,
        ),
        Reads => $read_cnt,
        'Reads Assembled' => $assembled_read_cnt,
        'Reads Assembled Success' => sprintf(
            '%.2f',
            100 * $assembled_read_cnt / $read_cnt,
        ),
        'Reads Assembled Minimum' => $reads[0],
        'Reads Assembled Maximum' => $reads[$#reads],
        'Reads Assembled Median' => $reads[( $#reads / 2 )],
        'Reads Assembled Average' => sprintf(
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
