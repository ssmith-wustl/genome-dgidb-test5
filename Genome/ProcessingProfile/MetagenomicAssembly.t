#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 5;

BEGIN {use_ok('Genome::ProcessingProfile::MetagenomicAssembly');}

my %pp_params;

&fail_create('no name param', %pp_params);

$pp_params{name} = 'test_metagenomic_assembly';
&fail_create('no assembler name', %pp_params);

$pp_params{assembler_name} = 'velvet';
&fail_create('no sequencing platform', %pp_params);

$pp_params{sequencing_platform} = 'solexa';

my $metagenomic_assembly = Genome::ProcessingProfile::MetagenomicAssembly->create(%pp_params);
isa_ok($metagenomic_assembly, 'Genome::ProcessingProfile::MetagenomicAssembly');
exit;


sub fail_create {
    my $reason = shift;
    my %pp_params = @_;
    my $metagenomic_assembly;
    eval {
        $metagenomic_assembly = Genome::ProcessingProfile::MetagenomicAssembly->create(%pp_params);
    };
    ok(!$metagenomic_assembly, $reason);
}


