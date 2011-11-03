#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::ProcessingProfile::AmpliconAssembly') or die;

my %params = (
    name => '16S Test 27F to 1492R (907R)',
    assembler => 'phredphrap',
    assembly_size => 1465,
    primer_amp_forward => '18SEUKF:ACCTGGTTGATCCTGCCAG',
    primer_amp_reverse => '18SEUKR:TGATCCTTCYGCAGGTTCAC',
    primer_seq_forward => '502F:GGAGGGCAAGTCTGGT',
    primer_seq_reverse => '1174R:CCCGTGTTGAGTCAAA',
    purpose => 'composition',
    region_of_interest => '16S',
    sequencing_center => 'gsc',
    sequencing_platform => 'sanger',
);
my $pp = Genome::ProcessingProfile::AmpliconAssembly->create(%params);
ok($pp, 'create');

my %invalid_params = (
    primer_amp_forward => 'AAGGTGAGCCCGCGATGCGAGCTTAT',
    primer_amp_reverse => '55:55',
    sequencing_platform => 'super-seq',
    sequencing_center => 'monsanto',
    purpose => 'because',
);
for my $param ( keys %invalid_params ) {
    my $value = delete $params{$param};
    $params{$param} = $invalid_params{$param};
    ok(
        !Genome::ProcessingProfile::AmpliconAssembly->create(%params), 
        "create failed as expected w/ invalid param $param => $invalid_params{$param}",
    );
    $params{$param} = $value;
}

done_testing();
exit;

