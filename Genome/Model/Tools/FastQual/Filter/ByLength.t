#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

# use
use_ok('Genome::Model::Tools::FastQual::Filter::ByLength') or die;
use_ok('Genome::Model::Tools::Fastq::SetReader') or die;

# create fail
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(), 'Create w/o filter length');
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(filter_length => 'all'), 'Create w/ filter length => all');
ok(!Genome::Model::Tools::FastQual::Filter::ByLength->create(filter_length => 0), 'Create w/ filter length => 0');

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq-FilterByLength';
my $fastq1 = $base_dir.'/1.fastq';
my $fastq2 = $base_dir.'/2.fastq';

# valid create and execution
my $filter = Genome::Model::Tools::FastQual::Filter::ByLength->create(filter_length => 50);
ok($filter, 'Create 50bp filter ok');

# filter fail
eval{ # undef
    $filter->filter();
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/o array ref');
eval{ # string
    $filter->filter('aryref');
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/o array ref');
eval{ # empty ary ref
    $filter->filter([]);
};
diag($@);
like($@, qr/Expecting array ref of sequences/, 'failed as expected to filter w/ empty array');

my $reader = Genome::Model::Tools::Fastq::SetReader->create(
    fastq_files => [ $fastq1, $fastq2 ],
);

my $ct = 0;
while (my $pairfq = $reader->next ) {
    my $filter_pairfq = $filter->filter($pairfq);
    $ct++ if $filter_pairfq;
}

is($ct, 9, '9 pairs are filtered ok as expected');
    
done_testing();
exit;

#HeadURL$
#$Id$
