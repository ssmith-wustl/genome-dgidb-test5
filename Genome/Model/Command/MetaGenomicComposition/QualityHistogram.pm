package Genome::Model::Command::MetaGenomicComposition::QualityHistogram;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Finishing::Assembly::Factory;
require GD::Graph::lines;
require IO::File;
use File::Grep 'fgrep';

class Genome::Model::Command::MetaGenomicComposition::QualityHistogram {
    is => 'Genome::Model::Command::MetaGenomicComposition',
};

#<>#
sub help_brief {
    return 'Creates a quality v. position histogram from the assembled and oriented fastas and quals for an MGC model';
}

sub help_detail {
    return help_brief();
}

sub sub_command_sort_position {
    return 40;
}

#<>#
sub execute {
    my $self = shift;
    # TODO retool to work on assembled fasta

    my $templates = $self->model->subclones_and_traces_for_assembly
        or return;
    while ( my ($subclone) = each %$templates) {
        $self->{_metrix}->{assemblies_attempted}++;
        my $contigs_file = sprintf('%s/%s.fasta.contigs', $self->model->consed_directory->edit_dir, $subclone);
        next unless -s $contigs_file;
        my $acefile = sprintf('%s/%s.fasta.ace', $self->model->consed_directory->edit_dir, $subclone);
        my $factory = Finishing::Assembly::Factory->connect('ace', $acefile);
        my $contigs = $factory->get_assembly->contigs;
        my $contig = $contigs->first;
        unless ( $contig ) {
            $self->error_message("No contigs found in acefile ($acefile)");
            return;
        }

        # Need to have at least one read
        my $reads = $contig->reads;
        my $reads_assembled = $reads->count;
        next unless $reads_assembled > 1;

        # Lengths
        $self->{_metrix}->{lengths_total} += $contig->unpadded_length;
        push @{ $self->{_metrix}->{lengths} }, $contig->unpadded_length;
        $self->{_metrix}->{assemblies_assembled}++;

        # Reads
        $self->{_metrix}->{reads_assembled_total} += $reads->count;
        push @{ $self->{_metrix}->{reads_assembled} }, $reads->count;
        my $reads_attempted = fgrep { /phd/ } sprintf('%s/%s.phds', $self->model->consed_directory->edit_dir, $subclone);
        unless ( $reads_attempted ) {
            $self->error_message(
                sprintf('No attempted reads in phds file (%s/%s.phds)', $self->model->consed_directory->edit_dir, $subclone)
            );
            return;
        }
        $self->{_metrix}->{reads_attempted_total} += $reads_attempted;
        push @{ $self->{_metrix}->{reads_attempted} }, $reads_attempted;
        
        # Need to complement? and have UP
        my ($need_to_complement, $have_UP) = $self->_determine_need_to_complement_and_have_UP_from_reads($reads);
        
        # Get quals
        my @quals = ( $need_to_complement )
        ? @{$contig->qualities}
        : reverse @{$contig->qualities};

        my $i = 1;
        if ( $#quals < $self->model->assembly_size and not $have_UP) { # not enough quals, need to move start
            $i = $self->model->assembly_size - $#quals;
        }

        my $qual_total = 0;
        my $qual20_bases = 0;
        $self->{_metrix}->{qual_by_pos}->{$reads_attempted} = [] unless exists $self->{_metrix}->{qual_by_pos}->{$reads_attempted};
        for my $qual ( @quals ) { 
            $qual_total += $qual;
            $qual20_bases++ if $qual >= 20;
            $self->{_metrix}->{qual_by_pos}->{$reads_assembled}->[$i++] += $qual;
        }

        $self->{_metrix}->{bases_qual_total} += $qual_total;
        $self->{_metrix}->{bases_greater_than_qual20} += $qual20_bases;

        $factory->disconnect;
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
            'Quality vs. Poistion Graph for %s (%s reads per assembly)', 
            $self->model->name,
            $self->{_metrix}->{reads_attempted_total} / $self->{_metrix}->{assemblies_assembled},
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

