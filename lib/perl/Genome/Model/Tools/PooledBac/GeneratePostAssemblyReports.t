#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Genome;

use Test::More skip_all => 'test data not in place yet....';
#exit;
#use Test::More tests => 5;

#BEGIN {
#    use_ok('Genome::Model::Tools::PooledBac::GenerateReports');
#}
use Genome::Model::Tools::PooledBac::GeneratePostAssemblyReports;
my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-PooledBac/';
my $pb_path = $path.'input_pb/';
my $project_dir = '/gscmnt/936/info/jschindl/pbtestout';
my $ace_file_name = 'pb.ace';
my $phd_ball = $pb_path.'consed/phdball_dir/phd.ball.1';


Genome::Model::Tools::PooledBac::GeneratePostAssemblyReports->execute(pooled_bac_dir=>$pb_path,ace_file_name => $ace_file_name,phd_file_name_or_dir => $phd_ball, project_dir => $project_dir);
1;
