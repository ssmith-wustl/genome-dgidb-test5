#!/gsc/bin/perl

use Test::More tests => 1;
use strict;
use warnings;

BEGIN {
    use_ok('Genome::Model::Tools::ManualReview::ViewWithConsed');
}

my $v = Genome::Model::Tools::ManualReview::ViewWithConsed->create();

ok($v->execute(),'execute with no options');

my $base_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-ManualReview/view-with-consed";

my $non_ex_dir = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-ManualReview/not-real-directory.txt";
my $not_real_file = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-ManualReview/not-real-file.txt";

my $v1 = Genome::Model::Tools::ManualReview::ViewWithConsed->create('ace_suffix' => 'ace',
                                                                    'review_list' => $non_ex_dir);

ok($v1->execute(),'list of non-existent directory');

my $v_unreal_file = Genome::Model::Tools::ManualReview::ViewWithConsed->create('ace_suffix' => 'ace',
                                                                    'review_list' => $not_real_file);

my $ret;
eval { $ret = $v_unreal_file->execute() ;};
is($ret,undef,'non existent review list file');


chdir($base_dir);
my $v2 = Genome::Model::Tools::ManualReview::ViewWithConsed->create('ace_suffix' => 'ace', );
ok($v2->execute(),'execute after changing into normal directory');

chdir($base_dir);
my $v3 = Genome::Model::Tools::ManualReview::ViewWithConsed->create('ace_suffix' => 'ace',
                                                                    'review_categories' => "Real_FS,Not_Real_FS",
                                                                    'review' => 1,
                                                                    );

ok($v3->execute());

