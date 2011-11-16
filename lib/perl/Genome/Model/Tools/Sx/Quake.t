#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::Quake') or die;

my %quake_params = map { $_ => 1 } Genome::Model::Tools::Quake->quake_param_names;
$quake_params{q} = 33;
my $quake_cmd = 'quake.py -f 1 --hash_size 1 --headers --int -k 1 -l 1 --log --no_count --no_cut --no_jelly -p 1 -q 33 -r 1 --ratio 1 -t 1 -u';
no warnings;
*Genome::Sys::shellcmd = sub{ 
    my ($self, %params) = @_;
    is($params{cmd}, $quake_cmd, 'quake command matches');
    return 1; 
};
use warnings;

my $quake = Genome::Model::Tools::Quake->create(%quake_params);
ok($quake, 'create');
$quake->dump_status_messages(1);
ok($quake->execute, 'execute');

done_testing();
exit;

