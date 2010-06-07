#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::DeNovoAssembly::Test') or die;

my $rv;

#< PP >#
# fail - no seq platform
eval{
    $rv = Genome::Model::DeNovoAssembly::Test->get_mock_model();
};
diag($@);
ok(
    !$rv && $@,
    'Failed as expected - get w/o seq platform',
);
# fail - no assembler
eval{
    $rv = Genome::Model::DeNovoAssembly::Test->get_mock_model(
        sequencing_platform => 'solexa',
    );
};
diag($@);
ok(
    !$rv && $@,
    'Failed as expected - create w/o assembler',
);
# fail - invalid seq platform/assembler combo
eval{
    $rv = Genome::Model::DeNovoAssembly::Test->get_mock_model(
        assembler_name => 'consed',
        sequencing_platform => 'solexa',
    );
};
diag($@);
ok(
    !$rv && $@,
    'Failed as expected - create w/ invalid seq paltform/assembler combo',
);

# valid 
my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    assembler_name => 'velvet',
    sequencing_platform => 'solexa',
);
ok($model, 'Got mock DNA model') or die;
my @inst_data = $model->instrument_data;
ok(@inst_data, 'Model instrument data');
ok(-s $inst_data[0]->archive_path, 'Solexa archive path exists');

done_testing();
exit;

#$HeadURL$
#$Id$
