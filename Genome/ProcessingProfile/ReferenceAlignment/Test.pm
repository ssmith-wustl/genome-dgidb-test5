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
        genotyper_name => undef,
        genotyper_params => undef,
        indel_finder_name => undef,
        indel_finder_params => undef,
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

#< VALID - CREATES A REAL PP >#
sub test001_create_processing_profile : Test(4) {
    my $self = shift;

    use_ok('Genome::ProcessingProfile::AmpliconAssembly');
    my $pp = Genome::ProcessingProfile::AmpliconAssembly->create( _valid_params() );
    ok($pp, 'Created amplicon assembly processing profile');
    isa_ok($pp, 'Genome::ProcessingProfile::AmpliconAssembly');
    isa_ok($pp, 'Genome::ProcessingProfile');

    return $pp;
}

#< INVALID >#
sub test002_invalid_params : Test(14) {
    my $self = shift;

    my %params = _valid_params();
    for my $param ( Genome::ProcessingProfile::AmpliconAssembly->params_for_class) {
        my $valid_value = delete $params{$param}; # save to ad back
        unless ( Genome::ProcessingProfile::AmpliconAssembly->param_is_optional($param) ) {
            # No param...
            ok(
                ! Genome::ProcessingProfile::AmpliconAssembly->create(%params),
                "Failed as expected - w/o $param",
            );
        }

        if ( Genome::ProcessingProfile::AmpliconAssembly->valid_values_for_param($param) ) {
            # Invalid param...
            $params{$param} = 'Not a valid value for a parameter';
            ok( 
                ! Genome::ProcessingProfile::AmpliconAssembly->create(%params),
                "Failed as expected - w/ an invalid value for $param",
            );
        }

        # Reset value
        $params{$param} = $valid_value;
    }

    #< Primers >#
    # none
    for ( keys %params ) { delete $params{$_} if /primer/; }
    ok( 
        ! Genome::ProcessingProfile::AmpliconAssembly->create(%params),
        "Failed as expected - w/o any primers",
    );
    # invlaid (no primer name)
    $params{primer_amp_forward} = 'AAGGTGAGCCCGCGATGCGAGCTTAT';
    ok( 
        ! Genome::ProcessingProfile::AmpliconAssembly->create(%params),
        "Failed as expected - w/ invalid primer string",
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
