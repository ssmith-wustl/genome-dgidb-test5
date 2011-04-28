package Genome::Model::Build::MetagenomicComposition16s::454;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::454 {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

sub calculate_estimated_kb_usage {
    # Based on the total reads in the instrument data. The build needs about 3 kb (use 3.5) per read.
    #  So request 5 per read or at least a MiB
    #  If we don't keep the classifications around, then we will have to lower this number.
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) { # very bad; should be checked when the build is create
        Carp::confess("No instrument data found for ".$self->description);
    }

    my $total_reads = 0;
    for my $instrument_data ( @instrument_data ) {
        $total_reads += $instrument_data->total_reads;
    }

    my $kb = $total_reads * 5;
    return ( $kb >= 1024 ? $kb : 1024 );
}

#< DIRS >#
sub _sub_dirs {
    return;
}

#< Amplicons >#
sub amplicon_set_names_and_primers {
    return (
        V1_V3 => [qw/
            ATTACCGCGGCTGCTGG 
        /],
        V3_V5 => [qw/ 
            CCGTCAATTCATTTAAGT
            CCGTCAATTCATTTGAGT
            CCGTCAATTCCTTTAAGT
            CCGTCAATTCCTTTGAGT
        /],
        V6_V9 => [qw/
            TACGGCTACCTTGTTACGACTT
            TACGGCTACCTTGTTATGACTT
            TACGGTTACCTTGTTACGACTT
            TACGGTTACCTTGTTATGACTT
        /],
    );
}

sub amplicon_set_names {
    my %set_names_and_primers = $_[0]->amplicon_set_names_and_primers;
    return sort keys %set_names_and_primers;
}

sub _amplicon_iterator_for_name {
    my ($self, $set_name) = @_;

    my $reader = $self->fasta_and_qual_reader_for_type_and_set_name('processed', $set_name);
    return unless $reader; # returns undef if no file exists OK or dies w/ error 

    my $amplicon_iterator = sub{
        my $seqs = $reader->read;
        return unless $seqs;
        my $seq = $seqs->[0];

        my $amplicon = Genome::Model::Build::MetagenomicComposition16s::Amplicon->create(
            name => $seq->{id},
            reads => [ $seq->{id} ],
            seq => $seq,
            classification_file => $self->classification_file_for_amplicon_name( $seq->{id} ),
        );

        unless ( $amplicon ) {
            die $self->error_message("Can't create amplicon for ".$seq->{id});
        }
        
        return $amplicon;
    };
    
    return $amplicon_iterator;
}

#< Clean Up >#
sub clean_up {
    my $self = shift;

    return 1;
}

#< prepare instrument data >#
sub filter_reads_by_primers {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) { # should not happen
        $self->error_message("No instrument data found for ".$self->description);
        return;
    }

    my %primers = $self->amplicon_set_names_and_primers;
    my $min_length = $self->processing_profile->amplicon_size;
    my $attempted = 0;
    for my $instrument_data ( @instrument_data ) {
        $self->status_message('PROCESSING: '.$instrument_data->id);
        unless ( $instrument_data->total_reads > 0 ) {
            $self->status_message('SKIPPING: '.$instrument_data->id.'. This instrument data does not have any reads, and will not have a fasta file.');
            next;
        }
        my $fasta_file = $instrument_data->dump_fasta_file;
        unless ( -s $fasta_file ) {
            $self->error_message('NO FASTA FILE: '.$instrument_data->id.'. This instrument data has reads, but no fasta file.');
            return;
        }

        my $reader = Genome::Model::Tools::FastQual::PhredReader->create(files => [ $fasta_file ]);
        $self->status_message('READING FASTA: '.$instrument_data->id);
        while ( my $fastas = $reader->read ) {
            my $fasta = $fastas->[0];
            $attempted++;
            # check length here
            next unless length $fasta->{seq} >= $min_length;
            my $set_name = 'none';
            my $seq = $fasta->{seq};
            REGION: for my $region ( keys %primers ) {
                for my $primer ( @{$primers{$region}} ) {
                    if ( $seq =~ s/^$primer// ) {
                        # check length again
                        $fasta->{seq} = $seq; # set new seq w/o primer
                        $set_name = $region;
                        last REGION; # go on to write 
                    }
                }
            }
            next unless length $fasta->{seq} >= $min_length;
            $fasta->{desc} = undef; # clear description
            my $writer = $self->_get_writer_for_set_name($set_name);
            $writer->write([$fasta]);
        }
        $self->status_message('DONE PROCESSING: '.$instrument_data->id);
    }

    $self->amplicons_attempted($attempted);

    return 1;
}


sub _get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);
        Carp::confess("Failed to create phred reader for amplicon set ($set_name)") if not $writer;
        $self->{$set_name} = $writer;
    }

    return $self->{$set_name};
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
