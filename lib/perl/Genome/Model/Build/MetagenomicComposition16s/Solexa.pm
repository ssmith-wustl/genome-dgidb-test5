package Genome::Model::Build::MetagenomicComposition16s::Solexa;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::Solexa {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

sub calculate_estimated_kb_usage {
    my $self = shift;

    my $instrument_data_count = $self->instrument_data_count;
    if ( not $instrument_data_count > 0 ) {
        Carp::confess( "No instrument data found for ".$self->description );
    }

    my $kb = $instrument_data_count * 500_000; #TODO .. not sure what best value is

    return ( $kb );
}

#< DIRS >#
sub _sub_dirs {
    return;
}

#< Amplicons >#
sub amplicon_set_names_and_primers { #TODO - these are 454 primer sets
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
    #looks like this should work with solexa (like 454 .. no qual)

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
