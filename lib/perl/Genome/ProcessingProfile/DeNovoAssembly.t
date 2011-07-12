#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Carp 'confess';
use Data::Dumper;
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS}, 'Dummy ids') or die;
$ENV{UR_DBI_NO_COMMIT} = 1;
ok($ENV{UR_DBI_NO_COMMIT}, 'DBI no commit') or die;

use_ok('Genome::ProcessingProfile::DeNovoAssembly') or die;

# Create fail - no seq platform
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'velvet one-button',
        assembler_version => '7.0.57-64',
    ),
    'Failed as expected - create w/o seq platform',
);
# Create fail - no assembler
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_version => '7.0.57-64',
    ),
    'Failed as expected - create w/o assembler',
);
# Create fail - invalid assembler
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'consed',
        assembler_version => '7.0.57-64',
    ),
    'Failed as expected - create w/ invalid assembler',
);
# Create fail - invalid coverage
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'velvet one-button',
        assembler_version => '7.0.57-64',
        coverage => -1,
    ),
    'Failed as expected - create w/ invalid coverage',
);
# Create fail - invalid assembler/platform combo
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'newbler',
        assembler_version => '7.0.57-64',
    ),
    'Failed as expected - create w/ invalid assembler and seq platform combo',
);
# Create fail - no assembler version
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'velvet one-button',
    ),
    'Failed as expected - create w/o assembler version',
);
# Create fail - invalid assembler params
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'velvet one-button',
        assembler_version => '7.0.57-64',
        assembler_params => '-wrong params',
    ),
    'Failed as expected - create w/ invalid assembler params',
);
# Create fail - calculated assembler params
ok(
    !Genome::ProcessingProfile::DeNovoAssembly->create(
        name => 'DNA Test',
        assembler_name => 'velvet one-button',
        assembler_version => '7.0.57-64',
        assembler_params => '-ins_length 260',
    ),
    'Failed as expected - create w/ calculated assembler params',
);

#< VELVET >#
my $pp = Genome::Model::DeNovoAssembly::Test->processing_profile_for_velvet;
ok($pp, 'Create DNA pp') or die;

my @stages = $pp->stages;
is_deeply(\@stages, [qw/ assemble /], 'Stages');

my @stage_classes = $pp->assemble_job_classes;
is_deeply(
    \@stage_classes, 
    [ 
        'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
        'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
        'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
        'Genome::Model::Event::Build::DeNovoAssembly::Report',
    ], 
    'Stage classes'
);
#is($pp->class_for_assembler, 'Genome::Model::Tools::Velvet::OneButton', 'Assembler class');
is($pp->assembler_class, 'Genome::Model::Tools::Velvet::OneButton', 'Assembler class');
#< SOAP >#
my $soap_pp = Genome::Model::DeNovoAssembly::Test->processing_profile_for_soap;
ok($soap_pp, "Created DNA pp") or die;
my @soap_stages = $soap_pp->stages;

is_deeply (\@soap_stages, [qw / assemble /], 'Stages');

my @soap_stage_classes = $soap_pp->assemble_job_classes;

is_deeply ( \@soap_stage_classes,
	    [
	     'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
	     'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
	     'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
	     'Genome::Model::Event::Build::DeNovoAssembly::Report',
	    ], 'Stage classes' );

done_testing();
exit;

