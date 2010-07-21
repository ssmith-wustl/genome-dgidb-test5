#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Newbler');

done_testing();
exit;

# FIXME !! Add newbler test data!!
my $pp = Genome::Model::DeNovoAssembly::Test->get_mock_processing_profile(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($pp, 'Got mock de novo assembly processing profile') or die;
my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    processing_profile => $pp,
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->add_mock_build_to_model($model);
ok($build, 'Got mock de novo assembly build') or die;

my $newbler = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Newbler->create( build_id => $build->id);
ok($newbler, 'Created PostAssemble newbler');
ok($newbler->execute, 'Execute PostAssemble newbler');

# TODO make sure it worked!

done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
