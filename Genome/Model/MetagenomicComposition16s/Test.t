#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Test') or die;

my $rv;

#< PP >#
# fail - no seq platform
eval{
    $rv = Genome::Model::MetagenomicComposition16s::Test->get_mock_model();
};
diag($@);
ok(
    !$rv && $@,
    'Failed as expected - get w/o seq platform',
);
# fail - invalid seq platform
eval{
    $rv = Genome::Model::MetagenomicComposition16s::Test->get_mock_model(
        sequencing_platform => 'solexa',
    );
};
diag($@);
ok(
    !$rv && $@,
    'Failed as expected - create w/ invalid sequencing platform',
);

# valid 
my $model = Genome::Model::MetagenomicComposition16s::Test->get_mock_model(
    sequencing_platform => '454',
);
ok($model, 'Got mock DNA model') or die;
my @inst_data = $model->instrument_data;
ok(@inst_data, 'Model instrument data');

done_testing();
exit;

#$HeadURL$
#$Id$
