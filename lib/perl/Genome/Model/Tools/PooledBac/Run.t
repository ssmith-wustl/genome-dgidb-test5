#!/usr/bin/env perl

use strict;
use warnings;
#use base qw(Test::Class);
use above 'Genome';
use Genome;

use Genome::Model::Tools::PooledBac::Run;

#use Test::More tests => 1;
use Test::More skip_all => "Test data not in place yet.";
#exit;
my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-PooledBac/';
my $pb_path = $path.'input_pb/';
my $ref_seq_file = $path.'ref_small.txt';
my $project_dir = '/gscmnt/936/info/jschindl/pbtestout';
my $ace_file_name = 'pb.ace';
`rm -rf $project_dir/*`;
`mkdir -p $project_dir`;

ok(Genome::Model::Tools::PooledBac::Run->execute(ref_seq_file=>$ref_seq_file,pooled_bac_dir=>$pb_path, project_dir => $project_dir, ace_file_name => 'pb.ace'), "PooledBac Run successful\n");
