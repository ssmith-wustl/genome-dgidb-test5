#!/gsc/bin/perl

use strict;
use warnings;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use Test::More tests => 11;
use above "Genome";

BEGIN {
    use_ok('Genome::ProcessingProfile::Assembly');
}

my $name = 'test';
my $read_filter = 'seqclean';
my $read_filter_params = 'test seqclean params';
my $read_trimmer = 'sfffile';
my $read_trimmer_params = 'test sfffile params';
my $assembler = 'newbler';
my $assembler_params = 'test newbler params';
my $sequencing_platform = '454';

my $assembly = Genome::ProcessingProfile::Assembly->create(
                                                           name => $name,
                                                           read_filter => $read_filter,
                                                           read_filter_params => $read_filter_params,
                                                           read_trimmer => $read_trimmer,
                                                           read_trimmer_params => $read_trimmer_params,
                                                           assembler => $assembler,
                                                           assembler_params => $assembler_params,
                                                           sequencing_platform => $sequencing_platform,
                                                       );
isa_ok($assembly,'Genome::ProcessingProfile::Assembly');
is($assembly->name,$name,'name accessor');
is($assembly->read_filter,$read_filter,'read_filter accessor');
is($assembly->read_filter_params,$read_filter_params,'read_filter_params accessor');
is($assembly->read_trimmer,$read_trimmer,'read_trimmer accessor');
is($assembly->read_trimmer_params,$read_trimmer_params,'read_trimmer_params accessor');
is($assembly->assembler,$assembler,'assembler accessor');
is($assembly->assembler_params,$assembler_params,'assembler_params accessor');
is($assembly->sequencing_platform,$sequencing_platform,'sequencing_platform accessor');

my @assemblies = Genome::ProcessingProfile::Assembly->get(
                                                          read_trimmer_params => $read_trimmer_params,
                                                      );
is(scalar(@assemblies),1,"expected 1 assembly processing profile with read_trimmer_params '$read_trimmer_params'");

exit;
