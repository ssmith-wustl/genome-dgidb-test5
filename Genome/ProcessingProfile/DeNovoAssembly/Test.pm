package Genome::ProcessingProfile::DeNovoAssembly::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper;
use Test::More;

sub test_class {
    'Genome::ProcessingProfile::DeNovoAssembly';
}

sub params_for_test_class {
    return params_for_test_class_solexa_velvet();
}

sub params_for_test_class_solexa_velvet {
    return (
	name => 'velvet solexa default params',
	assembler_name => 'velvet',
	assembler_version => '0.7.30',
	assembler_params => '-hash_length 27 ',
	sequencing_platform => 'solexa',
	prepare_instrument_data_params => '-reads_cutoff 10000',
    );
}

sub required_attrs {
    return (qw/ name assembler_name sequencing_platform /);
}

sub invalid_params_for_test_class {
    return (
	assembler_name => 'consed',
	sequencing_platform => '3730',
	assembler_params => '-wrong params',
	prepare_instrument_data_params => '-bad params',
	assembly_preprocess_params => '-fail test',
	);
}

#< Mock >#
sub create_mock_processing_profile {
    my ($self, %params) = @_;

    my $platform = delete $params{sequencing_platform};
    confess "No platform given to create mock processing profile\n" unless $platform;
    my $assembler = delete $params{assembler_name};
    confess "No assembler given to create mock processing profile\n" unless $assembler;

    my $params_method = 'params_for_test_class_'.$platform.'_'.$assembler;
    unless ($self->can($params_method) ) {
	confess "Invalid assembler ($assembler) and  platform ($platform) combination\n";
    }

    my $pp = $self->test_class->create_mock(
	id => -15000,
	$self->$params_method,
	);

    #Genome::ProcessingProfile
    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile',
        (qw/
            objects_for_stage classes_for_stage
            /),
    );
    #Genome::ProcessingProfile::DeNovoAssembly
    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile::DeNovoAssembly',
        (qw/ 
            stages get_assemble_params
                   get_prepare_instrument_data_params
                   get_preprocess_params
                   get_param_string_as_hash
                   assemble_objects assemble_job_classes
            /),
    );

    return $pp;

}

1;
