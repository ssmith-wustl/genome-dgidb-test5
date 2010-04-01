
###########################################################################

package Genome::Model::Build::MetagenomicComposition16s::Amplicon::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

require Bio::Seq::Quality;
use Data::Dumper 'Dumper';
use Test::More;

sub amplicon {
    return $_[0]->{_object};
}

sub test_class {
    'Genome::Model::Build::MetagenomicComposition16s::Amplicon';
}

sub params_for_test_class {
    my $self = shift;
    my $bioseq = $self->_bioseq;
    return (
        name => $bioseq->id,
        #directory => '/gsc/var/cache/testsuite/data/Genome-Model-AmpliconAssembly/edit_dir',
        reads => [qw/ 
            HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
            HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 
        /],
        bioseq => $bioseq,
        classification_file => '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build/classification/HMPB-aad13e12.classification.stor',
    );
}

sub _bioseq {
    my $self = shift;

    unless ( $self->{_bioseq} ) {
        $self->{_bioseq} = Bio::Seq->new(
            '-id' => 'HMPB-aad13e12',
            '-seq' => 'ATTACCGCGGCTGCTGGCACGTAGCTAGCCGTGGCTTTCTATTCCGGTACCGTCAAATCCTCGCACTATTCGCACAAGAACCATTCGTCCCGATTAACAGAGCTTTACAACCCGAAGGCCGTCATCACTCACGCGGCGTTGCTCCGTCAGACTTTCGTCCATTGCGGAAGATTCCCCACTGCTGCCTCCCGTAGGAGTCTGGGCCGTGTCTCAGTCCCAATGTGGCCGTTCATCCTCTCAGACCGGCTACTGATCATCGCCTTGGTGGGCCGTTACCCCTCCAACTAGCTAATCAGACGCAATCCCCTCCTTCAGTGATAGCTTATAAATAGAGGCCACCTTTCATCCAGTCTCGATGCCGAGATTGGGATCGTATGCGGTATTAGCAGTCGTTTCCAACTGTTGTCCCCCTCTGAAGGGCAGGTTGATTACGCGTTACTCACCCGTTCGCCACTAAGATTGAAAGAAGCAAGCTTCCATCGCTCTTCGTTCGACTTGCATGTGTTAAGCACGCCG',
        ),
    }

    return $self->{_bioseq};
}

sub test01_accessors : Tests {
    my $self = shift;

    my $bioseq = $self->_bioseq;
    my $amplicon = $self->amplicon;
    is($amplicon->name, $bioseq->id, 'name');
    ok($amplicon->oriented_bioseq, 'oriented bioseq');
    ok($amplicon->classification, 'classification');

    return 1;
}

###########################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

