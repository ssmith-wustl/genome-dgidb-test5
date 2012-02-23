#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::MockObject;
use Test::More;
require File::Temp;
require File::Path;

use_ok('Genome::Model::Tools::AmpliconAssembly::Set') or die;

my $base_test_dir = '/gsc/var/cache/testsuite/data';
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    
my $amplicon_assembly = Genome::Model::Tools::AmpliconAssembly::Set->get(
    directory => $base_test_dir.'/Genome-Model/AmpliconAssembly/build',
);
ok($amplicon_assembly, 'get amplicon assembly');

my $create_amplicon_assembly = Genome::Model::Tools::AmpliconAssembly::Set->create(
    directory => $tmp_dir,
);
ok($create_amplicon_assembly, 'create');
unlink $create_amplicon_assembly->_properties_file;
$create_amplicon_assembly->delete;

my %invalid_params = (
    sequencing_center => 'washu',
    sequencing_platform => '373',
);
for my $invalid_attr ( keys %invalid_params ) {
    ok(!Genome::Model::Tools::AmpliconAssembly::Set->create(
            directory => $tmp_dir,
            $invalid_attr => $invalid_params{$invalid_attr},
        ),
        "failed as expected - create w/ $invalid_attr\: ".$invalid_params{$invalid_attr},
    );
}

ok(
    !Genome::Model::Tools::AmpliconAssembly::Set->create(
        directory => $tmp_dir,
        sequencing_center => 'broad',
        exclude_contaminated_amplicons => 1,
    ), 'Failed as expected - create w/ unsupported attrs for broad',
);

# amplicons
my $amplicons = $amplicon_assembly->get_amplicons;
is_deeply(
    [ map { $_->name } @$amplicons ],
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 5 amplicons',
);
# reads for amplicon
my @reads = $amplicon_assembly->get_all_amplicons_reads_for_read_name(
    ($amplicons->[0]->reads)[0],
);
is_deeply(\@reads, $amplicons->[0]->get_reads, 'Got all amplicons reads for read name');

# get amplicons excluding contaminated and using only new recent read
my %mock_reads = _create_mock_gsc_sequence_reads() or die;
no warnings 'redefine';
local *Genome::Model::Tools::AmpliconAssembly::Set::_get_gsc_sequence_read = sub{ 
    die "No mock read for ".$_[1] unless exists $mock_reads{$_[1]};
    return $mock_reads{$_[1]};
};
$amplicon_assembly->exclude_contaminated_amplicons(1);
my $uncontaminated_amplicons = $amplicon_assembly->get_amplicons;
is_deeply(
    [ map { $_->name } @$uncontaminated_amplicons ],
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 4 uncontaminated amplicons using all read iterations',
);
$amplicon_assembly->only_use_latest_iteration_of_reads(1);
my $only_latest_reads_amplicons = $amplicon_assembly->get_amplicons;
is_deeply(
    [ map { $_->name } @$only_latest_reads_amplicons ],
    # we get all 5 amplicons here because the read that is contaminated is older
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 5 uncontaminated amplicons using only latest read iterations',
);
is_deeply(
    $only_latest_reads_amplicons->[0]->get_reads,
    [qw/ 
    HMPB-aad13a05.b3
    HMPB-aad13a05.b4
    HMPB-aad13a05.g1
    /],
    'Got latest iterations for reads'
);

done_testing();
exit;

sub _create_mock_gsc_sequence_reads {
    my %reads;
    my %read_params = (
        'HMPB-aad13a05.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.g1' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.g2' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            # CONTAMINATED READ #
            'is_contaminated' => 1,
        },
        'HMPB-aad15e03.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
    );
    for my $read_name ( keys %read_params ) {
        $reads{$read_name} = Test::MockObject->new();
        $reads{$read_name}->set_always('trace_name', $read_name);
        my $screen_reads_stat_hmp = Test::MockObject->new();
        $screen_reads_stat_hmp->set_always(
            'is_contaminated',
            $read_params{$read_name}->{is_contaminated}
        );
        $reads{$read_name}->set_always('get_screen_read_stat_hmp', $screen_reads_stat_hmp);
        for my $attr ( keys %{$read_params{$read_name}} ) {
            $reads{$read_name}->set_always($attr, $read_params{$read_name}->{$attr});
        }
    }

    return %reads;
}

