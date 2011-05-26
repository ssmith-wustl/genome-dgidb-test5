#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use File::Temp;
use Test::More;# tests => 4;

use_ok('Genome::Model::Tools::Velvet::ToAce');

#test suite dir
my $root_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/ToAce';

#test dir
my $run_dir = Genome::Sys->create_temp_directory();
ok( -d $run_dir, "Create test dir" );

#link input files
for my $file (qw/  Sequences velvet_asm.afg / ) {
    ok( -s $root_dir."/$file", "input $file exists" );
    symlink( $root_dir."/$file", $run_dir."/$file" );
    ok( -s $root_dir."/$file", "linked input file" );
}

#create/execute tool
my $ta = Genome::Model::Tools::Velvet::ToAce->create(
    assembly_directory => $run_dir,
    time        => 'Wed Jul 29 10:59:26 2009',
);

ok($ta, 'to-ace creates ok');
ok($ta->execute, 'velvet to-ace runs ok');

#check ace file
my $out_ace = $run_dir.'/edit_dir/velvet_asm.ace';
ok( -s $out_ace, "Created ace file" );

my $ori_ace = $root_dir.'/velvet_asm.ace';
ok( -s $ori_ace, "Test ace file exists" );

my @diff = `diff $out_ace $ori_ace`;
my @lines = ();
for my $diff (@diff) {
    next if $diff =~ /comment\sVelvetToAce|Run\sby/;
    push @lines, $diff;
}

is(scalar @lines, 2, 'Ace file converted from velvet output is OK');

done_testing();

exit;
