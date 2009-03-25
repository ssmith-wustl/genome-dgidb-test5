package Genome::Model::AmpliconAssembly::Report::QualityHistogram;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require GD::Graph::lines;
require IO::File;
use File::Grep 'fgrep';

class Genome::Model::AmpliconAssembly::Report::QualityHistogram {
    is => 'Genome::Model::AmpliconAssembly::Report',
};

sub _generate_data {
    my $self = shift;
    # TODO retool to work on assembled fasta

    #my $amplicons = $self->model->amplicons
    #   or return;

    my $oriented_fasta = $self->model->orientation_confirmed_fasta;
    my $oriented_qual = "$oriented_fasta.qual";
    unless ( -s $oriented_fasta ) {
        $self->error_message("Confirmed orientation fasta ($oriented_fasta) file does not exist.");
        return;
    }
    
    my $bioseq_io = Bio::SeqIO->new(
        '-file' => $oriented_qual,
        '-format' => 'qual',
    );

    while ( my $bioseq = $bioseq_io->next_seq ) {
        my %src_info = map { split('=') } split(' ', $bioseq->desc);
        next unless $src_info{reads} > 1;

        # Lengths
        $self->{_metrix}->{lengths_total} += $bioseq->length;
        push @{ $self->{_metrix}->{lengths} }, $bioseq->length;
        $self->{_metrix}->{assemblies_assembled}++;

        # Reads
        $self->{_metrix}->{reads_assembled_total} += $src_info{reads};
        push @{ $self->{_metrix}->{reads_assembled} }, $src_info{reads};
        
        my $i = 1;
        my $last_qual_pos = @{$bioseq->qual} - 1;
        if ( $last_qual_pos < $self->model->assembly_size ) { # not enough quals, need to move start
            $i = $self->model->assembly_size - $last_qual_pos;
        }

        my $qual_total = 0;
        my $qual20_bases = 0;
        $self->{_metrix}->{qual_by_pos}->{$src_info{reads}} = [] unless exists $self->{_metrix}->{qual_by_pos}->{$src_info{reads}};
        for my $qual ( @{$bioseq->qual} ) { 
            $qual_total += $qual;
            $qual20_bases++ if $qual >= 20;
            $self->{_metrix}->{qual_by_pos}->{$src_info{reads}}->[$i++] += $qual;
        }

        $self->{_metrix}->{bases_qual_total} += $qual_total;
        $self->{_metrix}->{bases_greater_than_qual20} += $qual20_bases;
    }

    unless ( $self->{_metrix}->{assemblies_assembled} ) {
        $self->error_message( sprintf('No assemblies for %s', $self->model->name) );
        return;
    }

    #print Dumper($self->{_metrix});
    $self->_create_histogram;

    return 1;
}

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
            $self->model->name,
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
        x_max_value       => $self->model->assembly_size,
        x_tick_number     => int($self->model->assembly_size / 100),
        x_label_skip      => 0,
        x_number_format   => '%.0f',
    ) 
        or ( $self->error_message( $graph->error ) and return );
    $graph->set(dclrs => [qw/ dblue gold dyellow dgreen dred dpurple lbrown marine black dbrown /]); # data colors
    $graph->set_text_clr('dblue');

    my @data = ( [ 1..$self->model->assembly_size ] );
    my %reads_assembled_and_assemblies;
    for my $reads_assembled( @{$self->{_metrix}->{reads_assembled}} ) {
        $reads_assembled_and_assemblies{$reads_assembled}++;
    }

    $graph->set_legend(
        map { 
            sprintf(
                '%s reads in %s assemblies', 
                $_, 
                $reads_assembled_and_assemblies{$_}
            )
        } sort keys %reads_assembled_and_assemblies
    )
        or ( $self->error_message( $graph->error ) and return );

    for my $read_count ( sort { $a <=> $b } keys %reads_assembled_and_assemblies ) {
        push @data, [ 
        map { 
            ($_ || 0) / $reads_assembled_and_assemblies{$read_count}
        } @{$self->{_metrix}->{qual_by_pos}->{$read_count}}
        ];
    }

    # print Dumper(\@data);
    my $gd = $graph->plot(\@data)
        or ( $self->error_message( $graph->error ) and return );

    my $file = $self->model->quality_histogram_file;
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

1;

=pod

=head1 Name

Modulesubclone

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

