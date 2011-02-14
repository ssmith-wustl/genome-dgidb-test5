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
        my $bioseq = $reader->next_seq;
        return unless $bioseq;

        my $amplicon = Genome::Model::Build::MetagenomicComposition16s::Amplicon->create(
            name => $bioseq->id,
            reads => [ $bioseq->id ],
            bioseq => $bioseq,
            classification_file => $self->classification_file_for_amplicon_name( $bioseq->id ),
        );

        unless ( $amplicon ) {
            die $self->error_message("Can't create amplicon for ".$bioseq->id);
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
