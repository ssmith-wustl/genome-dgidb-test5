package Genome::ProcessingProfile::ReferenceAlignment::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Test::More;
use Genome::Utility::TestBase;

sub test_dir {
    #return '/gsc/var/cache/testsuite/data/Genome-ProcessingProfile-AmpliconAssembly';
}

sub _valid_params {
    return (
        name => 'New Maq Test',
        sequencing_platform => 'solexa',
        dna_type => 'genomic dna',
        snv_detection_strategy => 'maq',
        multi_read_fragment_strategy => undef,
        read_aligner_name => undef,
        read_aligner_version => undef,
        read_aligner_params => undef,
        read_calibrator_name => undef,
        read_calibrator_params => undef,
        prior_ref_seq => undef,
        reference_sequence_name => undef,
        align_dist_threshold => undef,
    );
}

#< MOCK ># 
sub create_mock_processing_profile {
    my $self = shift;

    my %valid_params = $self->_valid_params;
    my $pp = Genome::ProcessingProfile::ReferenceAlignment->create_mock( 
        id => -50001,
        processing_profile_id => -50001,
        %valid_params,
    )
        or die "Can't create mock processing profile for reference alignment\n";

    $pp->set_list('params_for_class', Genome::ProcessingProfile::ReferenceAlignment->params_for_class);
    for my $key ( keys %valid_params ) {
        $pp->set_always($key, $valid_params{$key});
    }

    return $pp;
}

1;

#$HeadURL$
#$Id$
