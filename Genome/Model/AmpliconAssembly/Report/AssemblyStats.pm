package Genome::Model::AmpliconAssembly::Report::AssemblyStats;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use XML::LibXML;

class Genome::Model::AmpliconAssembly::Report::AssemblyStats {
    is => 'Genome::Model::AmpliconAssembly::Report',
    has => [
    name => {
        default_value => 'Assembly Stats',
    },
    description => {
        calculate_from => [qw/ model_name build_id /],
        calculate => q| 
        return sprintf(
            'Assembly Stats for Amplicon Assembly (Name <%s> Build Id <%s>)',
            $self->model_name,
            $self->build_id,
        );
        |,
    },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    $self->{_metrix} = {
        # stats
        assembled => 0,
        attempted => 0,
        lengths => [],
        qual => 0,
        qual_gt_20 => 0,
        reads => [],
        reads_assembled => [],
        # qual
        read_counts => {}, # redundant
        qual_by_pos => {},
    };

    return $self;
}

sub _generate_data {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons;
    unless ( $amplicons ) {
        $self->error_message( sprintf("No amplicons for build (ID %s)", $self->build->id) );
        return;
    }
    for my $amplicon ( @$amplicons ) {
        $self->add_amplicon($amplicon)
            or return;
    }

    # Stats 
    $self->_add_stats_dataset
        or return;

    # Qual
    $self->_add_quality_dataset
        or return;

    return 1;
}

sub add_amplicon {
    my ($self, $amplicon) = @_;

    $self->{_metrix}->{attempted}++;

    return 1 unless $amplicon->was_assembled_successfully;

    $self->{_metrix}->{assembled}++;

    # Length
    my $bioseq = $amplicon->get_bioseq;
    unless( $bioseq ) { # very bad
        $self->error_message('Amplicon '.$amplicon->get_name.' was assembled succeszsfully, but counld not get bioseq.');
        return;
    }
    push @{$self->{_metrix}->{lengths}}, $bioseq->length;

    # Get quals
    for my $qual ( @{$bioseq->qual} ) { 
        $self->{_metrix}->{qual} += $qual;
        $self->{_metrix}->{qual_gt_20}++ if $qual >= 20;
    }

    # Reads
    push @{ $self->{_metrix}->{reads} }, $amplicon->get_read_count;
    my $read_count = $amplicon->get_assembled_read_count;
    push @{ $self->{_metrix}->{reads_assembled} }, $read_count;
    $self->{_metrix}->{read_counts}->{$read_count}++;

    return 1 unless $amplicon->is_bioseq_oriented;
    
    my $i = 1;
    my $last_qual_pos = @{$bioseq->qual} - 1;
    if ( $last_qual_pos < $self->build->model->assembly_size ) { # not enough quals, need to move start
        $i = $self->build->model->assembly_size - $last_qual_pos;
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

sub _add_stats_dataset {
    my $self = shift;

    my $attempted = $self->{_metrix}->{attempted};
    unless ( $attempted ) {
        $self->error_message("Cannot calculate totals because no amplicons added");
        return;
    }

    my $sum = sub{
        my $total = 0;
        for ( @_ ) { $total += $_; }
        return $total;
    };

    my $assembled = $self->{_metrix}->{assembled};
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

    return $self->_add_dataset(
        name => 'stats',
        row_name => 'stat',
        headers => [ sort { $a cmp $b } keys %totals ],
        rows => [[ map { $totals{$_} } sort { $a cmp $b } keys %totals ]], # only one row
    );
}

sub _add_quality_dataset {
    my $self = shift;

    my %read_counts;
    for my $read_count ( @{$self->{_metrix}->{reads_assembled}} ) {
        $read_counts{$read_count}++;
    }
    
    for my $read_count ( sort { $a <=> $b } keys %read_counts ) {
        $self->_add_dataset(
            name => 'qualities',
            label => 'read-count-'.$read_count,
            'length' => $self->build->model->assembly_size,
            row_name => 'quality',
            headers => [qw/ value /],
            rows => [ 
            map { 
                [ sprintf('%.0f', ($_ || 0) / $read_counts{$read_count}) ]
            } @{$self->{_metrix}->{qual_by_pos}->{$read_count}}
            ],
        );
    }

    return 1;
}

=cut
This creates a histogram.  We will prolly do this in a web page instead
sub _create_histogram {
    my $self = shift;

    my $graph = GD::Graph::lines->new(1000, 400);
    unless ( $graph ) {
        $self->error_message("Can't create GD::Graph: $!");
        return;
    }
    $graph->set(
        # titles
        title             => sprintf(
            'Quality vs. Poistion Graph for %s', 
            $self->model_name,
        ),
        x_label           => 'Position',
        y_label           => 'Quality',
        # colors
        transparent => 0,
        bgclr             => 'lgray',
        fgclr             => 'dgray',
        boxclr            => 'white',
        # graph format
        long_ticks        => 1,
        l_margin          => 20,
        r_margin          => 20,
        t_margin          => 20,
        b_margin          => 20,
        # y
        y_min_value       => 0,
        y_max_value       => 100,
        y_tick_number     => 10,
        y_label_skip      => 0,
        # x
        x_min_value       => 1,
        x_max_value       => $self->build->model->assembly_size,
        x_tick_number     => int($self->build->model->assembly_size / 100),
        x_label_skip      => 0,
        x_number_format   => '%.0f',
    ) 
        or ( $self->error_message( $graph->error ) and return );
    $graph->set(dclrs => [qw/ dblue gold dyellow dgreen dred dpurple lbrown marine black dbrown /]); # data colors
    $graph->set_text_clr('dblue');

    my @data = ( [ 1..$self->build->model->assembly_size ] );
    my $read_counts = $self->{_metrix}->{read_counts};

    $graph->set_legend(
        map { 
            sprintf(
                '%s reads in %s assemblies', 
                $_, 
                $read_counts->{$_}
            )
        } sort keys %$read_counts
    )
        or ( $self->error_message( $graph->error ) and return );

    for my $read_count ( sort { $a <=> $b } keys %$read_counts ) {
        push @data, [ 
        map { 
            ($_ || 0) / $read_counts->{$read_count}
        } @{$self->{_metrix}->{qual_by_pos}->{$read_count}}
        ];
    }

    # print Dumper(\@data);
    my $gd = $graph->plot(\@data)
        or ( $self->error_message( $graph->error ) and return );

    #my $file = $self->build->quality_histogram_file;
    my $file = '/gscuser/ebelter/Desktop/reports/qh.png';
    unlink $file if -e $file;
    my $fh = IO::File->new($file, 'w');
    unless ( $fh ) { 
        $self->error_message("Can't open file ($file): $!");
        return;
    }
    $fh->binmode;
    $fh->print( $gd->png );

    return $fh->close;
}
=cut

1;

#$HeadURL$
#$Id$
