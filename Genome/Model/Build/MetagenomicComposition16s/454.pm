package Genome::Model::Build::MetagenomicComposition16s::454;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require Bio::SeqIO;

class Genome::Model::Build::MetagenomicComposition16s::454 {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

#< DIRS >#
sub _sub_dirs {
    return;
}

#< Amplicons >#
sub amplicon_iterator {
    my $self = shift;

    my $reader = $self->processed_fasta_and_qual_reader
        or return;

    my $amplicon_iterator = sub{
        my $bioseq = $reader->();
        return unless $bioseq;

        my $amplicon = Genome::Model::Build::MetagenomicComposition16s::Amplicon->create(
            name => $bioseq->id,
            reads => [ $bioseq->id ],
            bioseq => $bioseq,
        );

        $self->load_classification_for_amplicon($amplicon); # dies on error
        
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
