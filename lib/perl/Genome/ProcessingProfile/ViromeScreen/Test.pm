package Genome::ProcessingProfile::ViromeScreen::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper;
use Test::More;

sub test002_create { #: Test(1) {
# overload this for now. move to PP:Test, don't create cuz only one options 
    return 1;
}

sub test_class {
    'Genome::ProcessingProfile::ViromeScreen';
}

sub params_for_test_class {
    return params_for_test_class_454_virome_screen();
}

sub params_for_test_class_454_virome_screen {
    return (
	name => 'virome screen default test',
	sequencing_platform => '454',
    );
}

sub required_attrs {
    return (qw/ name sequencing_platform /);
}

sub invalid_params_for_test_class {
    return (
	sequencing_platform => 'solexa',
    );
}

#< Mock >#
sub create_mock_processing_profile {
    my ($self, %params) = @_;

    my $platform = delete $params{sequencing_platform};
    confess "No platform given to create mock processing profile\n" unless $platform;

    my $params_method = 'params_for_test_class_'.$platform.'_virome_screen';
    unless ($self->can($params_method) ) {
	confess "Invalid sequencing platform for virome screen\n";
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
            objects_for_stage
            classes_for_stage
        /),
    );

    #Genome::ProcessingProfile::ViromeScreen
    $self->mock_methods(
        $pp,
        'Genome::ProcessingProfile::ViromeScreen',
        (qw/ stages screen_objects screen_job_classes /),
    );

    return $pp;

}

1;
