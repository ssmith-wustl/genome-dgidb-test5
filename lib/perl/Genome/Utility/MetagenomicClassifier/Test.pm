package Genome::Utility::MetagenomicClassifier::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use File::Temp 'tempdir';
use Storable qw/ nstore retrieve /;
use Test::More;

sub dir { 
    return '/gsc/var/cache/testsuite/data/Genome-Utility-MetagenomicClassifier';
}

sub fasta {
    return $_[0]->dir.'/U_PR-JP_TS1_2PCA.fasta';
}

#< RDP >#
sub rdp_file {
    return $_[0]->dir.'/U_PR-JP_TS1_2PCA.fasta.rdp';
}

sub tmp_rdp_file {
    return $_[0]->tmp_dir.'/U_PR-JP_TS1_2PCA.fasta.rdp';
}

#< Classifications Objects >#
sub classifications_stor {
    return $_[0]->dir.'/classifications.stor';
}

sub retrieve_classifications {
    return retrieve( $_[0]->classifications_stor );
}

sub store_classifications {
    my ($self, $classifications) = @_;
    return nstore($classifications, $self->classifications_stor);
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::SequenceClassification::Test;

use strict;
use warnings;

use base 'Genome::Utility::MetagenomicClassifier::TestBase';

use Bio::Taxon;
use Genome::Utility::MetagenomicClassifier;
use Test::More;

sub sequence_classification {
    return $_[0]->{_object};
}

sub test_class {
    return 'Genome::Utility::MetagenomicClassifier::SequenceClassification';
}

sub params_for_test_class {
    my $self = shift;

    my %params = $self->_get_string_params;
    $params{taxon} = $self->_get_taxon;

    return %params;
}

sub _get_string_params{
    return (
        name => 'U_PR-aab10d09',
        complemented => 0,
        classifier => 'rdp',
    );
}

sub _get_taxon {
    my @taxa;
    my $string = 'Root:1.0;Bacteria:1.0;Eubacteria:1.0;Bacteroidetes:0.99;Bacteroidetes:0.82;Bacteroidales:0.82;Rikenellaceae:0.78;Alistipes:0.68;Alistipes carmichaelli:0.68';
    my @ranks = Genome::Utility::MetagenomicClassifier->taxonomic_ranks;
    unshift @ranks, 'root';
    for my $assignment ( split(';', $string) ) {
        my ($name, $conf) = split(':', $assignment);
        push @taxa, Genome::Utility::MetagenomicClassifier->create_taxon(
            id => $name,
            rank => shift(@ranks),
            tags => {
                confidence => $conf,
            },
            ancestor => ( @taxa ? $taxa[$#taxa] : undef ),
        );
    }

    return $taxa[0];
}


sub test01_gets : Test(8) {
    my $self = shift;

    my $seq_classification = $self->sequence_classification;
    my %params = $self->_get_string_params;
    for my $key ( keys %params ) {
        my $method = 'get_'.$key;
        can_ok($seq_classification, $method);
        is($seq_classification->$method, $params{$key}, "Compared $key");
    }

    for my $method (qw/ get_taxon get_taxa /) {
        can_ok($seq_classification, $method);
    }

    return 1;
}

sub test02_taxons_and_names : Tests {
    my $self = shift;

    my $seq_classification = $self->sequence_classification;
    for my $rank ( 'root', Genome::Utility::MetagenomicClassifier->taxonomic_ranks ) {
        # taxon
        my $get_taxon_method = 'get_'.$rank.'_taxon';
        can_ok($seq_classification, $get_taxon_method);
        my $taxon = $seq_classification->$get_taxon_method;
        ok($taxon, "Got $rank taxon");
        is($taxon->rank, $rank, "Taxon is $rank");
        # name
        my $get_name_method = 'get_'.$rank;
        my $name = $seq_classification->$get_name_method;
        ok($name, "Got $rank name ($name) for taxon");
        is($taxon->id, $name, "Taxon name and $get_name_method match");
        # name and confidence
        my $get_conf_method = 'get_'.$rank.'_confidence';
        my $conf = $seq_classification->$get_conf_method;
        ok($conf, "Got confidence ($conf) for $rank with $get_conf_method");
        my ($conf_from_taxon) = $taxon->get_tag_values('confidence');
        is($conf, $conf_from_taxon, "Confidence from $get_conf_method and taxon match");
    }

    # Check that these private methods do not return stuff that doesn't exist
    ok(!$seq_classification->_get_taxon_for_rank('blah'), "As expected - no blah taxon");
    ok(!$seq_classification->_get_taxon_name_for_rank('blah'), "As expected - no blah taxon name");
    ok(!$seq_classification->_get_taxon_confidence_for_rank('blah'), "As expected - no blah confidence");

    return 1;
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::PopulationComposition::Test;

use strict;
use warnings;

use base 'Genome::Utility::MetagenomicClassifier::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub population_composition {
    return $_[0]->{_object};
}

sub test_class {
    return 'Genome::Utility::MetagenomicClassifier::PopulationComposition';
}

sub params_for_test_class { 
    return ( confidence_threshold => .8 );
}

sub required_attrs { 
    return;
}

sub test01_add_classifications : Test(1) {
    my $self = shift;
    
    my $population_composition = $self->population_composition;
    can_ok($population_composition, 'add_classification');
    my $classifications = $self->retrieve_classifications;
    for my $classification ( @$classifications ) { # should be 10
        $population_composition->add_classification($classification)
    }

    return 1;
}

sub test02_invalid_params : Test(1) {
    my $self = shift;

    my $eval;
    eval {
        $eval = $self->test_class->new(
            confidence_threhold => '1.5.5',
        );
    };

    diag("$@\n");
    ok(!$eval, 'Failed as expected - create w/ invalid confidence_threhold');

    return 1;
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::PopulationCompositionFactory::Test;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;

sub test001_use : Tests(2) {
    use_ok('Genome::Utility::MetagenomicClassifier::PopulationCompositionFactory')
        or die;
    use_ok('Genome::Utility::MetagenomicClassifier::Rdp')
        or die;
    return 1;
}

sub test003_get_composition : Tests(4) {
return 1;
    my $self = shift;

    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Test->create_broad_classifier;
    ok($classifier, 'Created rdp classifier');
    my $factory = Genome::Utility::MetagenomicClassifier::PopulationCompositionFactory->instance;
    ok($factory, 'Got factory instance');
    my $composition = $factory->get_composition(
        classifier => $classifier,
        fasta_file => Genome::Utility::MetagenomicClassifier::TestBase->fasta,
    );
    ok($composition, 'Got composition from factory');
    isa_ok($composition, 'Genome::Utility::MetagenomicClassifier::PopulationComposition');

    $self->{_composition} = $composition;

    return 1;
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::Rdp::Test;

use strict;
use warnings;

use base 'Test::Class';

use Bio::SeqIO;
use Test::More;

sub create_broad_classifier {
    return Genome::Utility::MetagenomicClassifier::Rdp::Version2x1->new(
        training_set => 'broad',
    );
}

sub create_rdp_classifier {
    return Genome::Utility::MetagenomicClassifier::Rdp->new(
    );
}

sub test001_require : Tests(1) {
    use_ok('Genome::Utility::MetagenomicClassifier::Rdp')
        or die;
    return 1;
}

sub test002_create : Tests(6) {
    my $self = shift;

    my $classifier = $self->create_rdp_classifier;

    my $version = $classifier->get_training_version;
    ok ($version ne '', 'Got training set version');
    ok($classifier, 'Created rdp classifier');

    $classifier = $self->create_broad_classifier;

    my $seq = Bio::Seq->new( 
        -display_id => 'S000002017 Pirellula staleyi', 
        -seq => 'AATGAACGTTGGCGGCATGGATTAGGCATGCAAGTCGTGCGCGATATGTAGCAATACATGGAGAGCGGCGAAAGGGAGAGTAATACGTAGGAACCTACCTTCGGGTCTGGGATAGCGGCGGGAAACTGCCGGTAATACCAGATGATGTTTCCGAACCAAAGGTGTGATTCCGCCTGAAGAGGGGCCTACGTCGTATTAGCTAGTTGGTAGGGTAATGGCCTACCAAGnCAAAGATGCGTATGGGGTGTGAGAGCATGCCCCCACTCACTGGGACTGAGACACTGCCCAGACACCTACGGGTGGCTGCAGTCGAGAATCTTCGGCAATGGGCGAAAGCCTGACCGAGCGATGCCGCGTGCGGGATGAAGGCCTTCGGGTTGTAAACCGCTGTCGTAGGGGATGAAGTGCTAGGGGGTTCTCCCTCTAGTTTGACTGAACCTAGGAGGAAGGnCCGnCTAATCTCGTGCCAGCAnCCGCGGTAATACGAGAGGCCCAnACGTTATTCGGATTTACTGGGCTTAAAGAGTTCGTAGGCGGTCTTGTAAGTGGGGTGTGAAATCCCTCGGCTCAACCGAGGAACTGCGCTCCAnACTACAAGACTTGAGGGGGATAGAGGTAAGCGGAACTGATGGTGGAGCGGTGAAATGCGTTGATATCATCAGGAACACCGGAGGCGAAGGCGGCTTACTGGGTCCTTTCTGACGCTGAGGAACGAAAGCTAGGGGAGCAnACGGGATTAGATACCCCGGTAGTCCTAnCCGTAAACGATGAGCACTGGACCGGAGCTCTGCACAGGGTTTCGGTCGTAGCGAAAGTGTTAAGTGCTCCGCCTGGGGAGTATGGTCGCAAGGCTGAAACTCAAAGGAATTGACGGGGGCTCACACAAGCGGTGGAGGATGTGGCTTAATTCGAGGCTACGCGAAGAACCTTATCCTAGTCTTGACATGCTTAGGAATCTTCCTGAAAGGGAGGAGTGCTCGCAAGAGAGCCTnTGCACAGGTGCTGCATGGCTGTCGTCAGCTCGTGTCGTGAGATGTCGGGTTAAGTCCCTTAACGAGCGAAACCCTnGTCCTTAGTTACCAGCGCGTCATGGCGGGGACTCTAAGGAGACTGCCGGTGTTAAACCGGAGGAAGGTGGGGATGACGTCAAGTCCTCATGGCCTTTATGATTAGGGCTGCACACGTCCTACAATnGTGCACACAAAGCGACGCAAnCTCGTGAGAGCCAGCTAAGTTCGGATTGCAGGCTGCAACTCGCCTGCATGAAGCTGGAATCGCTAGTAATCGCGGGTCAGCATACCGCGGTGAATGTGTTCCTGAGCCTTGTACACACCGCCCGTCAAGCCACGAAAGTGGGGGGGACCCAACAGCGCTGCCGTAACCGCAAGGAACAAGGCGCCTAAGGTCAACTCCGTGATTGGGACTAAGTCGTAACAAGGTAGCCGTAGGGGAACCTGCGGCTGGATCACCTCCTT',
    );

    my $classification = $classifier->classify($seq);
    ok($classification, 'got classification from classifier');
    isa_ok($classification, 'Genome::Utility::MetagenomicClassifier::SequenceClassification');
    my $taxon = $classification->get_taxon;
    do {
        ($taxon) = $taxon->each_Descendent;
    } until ($taxon->is_Leaf()); 

    ok($taxon->id eq 'Pirellula', 'found correct classification');

    my ($conf) = $taxon->get_tag_values('confidence');

    ok($conf == 1.0, 'found correct confidence value');

    return 1;
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::ChimeraClassifier::Test;

use strict;
use warnings;

use base 'Test::Class';

use Bio::SeqIO;
use Test::More;

sub create_broad_classifier {
    return Genome::Utility::MetagenomicClassifier::ChimeraClassifier->create(
        training_set => 'broad',
    );
}

sub test001_require : Tests(1) {
    use_ok('Genome::Utility::MetagenomicClassifier::ChimeraClassifier')
        or die;
    return 1;
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::ChimeraClassification::Writer::Test;

use strict;
use warnings;

use base 'Genome::Utility::MetagenomicClassifier::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;

sub test_class {
    return 'Genome::Utility::MetagenomicClassifier::ChimeraClassification::Writer';
}

#####################################################################################################

package Genome::Utility::MetagenomicClassifier::Rdp::Reader::Test;

use strict;
use warnings;

use base 'Genome::Utility::MetagenomicClassifier::TestBase';

use Test::More;

sub test_class {
    return 'Genome::Utility::MetagenomicClassifier::Rdp::Reader';
}

sub params_for_test_class { 
    return ( input => $_[0]->rdp_file );
}

sub test003_read_and_compare : Test(3) {
    my $self = shift;

    my @classifications = $self->{_object}->all;
    #$self->store_classifications(\@classifications);
    ok(@classifications, 'Got classifications from reader');
    my $expected_classifications = $self->retrieve_classifications;
    is(scalar(@classifications), scalar(@$expected_classifications), 'Got the correct number of classifications');
    is_deeply(\@classifications, $expected_classifications, 'Generated and expected classification objects match');

    return 1;
}

#####################################################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
