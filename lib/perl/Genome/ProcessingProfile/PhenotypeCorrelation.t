package Genome::ProcessingProfile::PhenotypeCorrelation;
use strict;
use warnings;
use above "Genome";
use Test::More tests => 11;

use Genome::ProcessingProfile::PhenotypeCorrelation;

my $asms_cohort = Genome::PopulationGroup->get(name => 'ASMS-cohort-TGI-2011');

unless ($asms_cohort) {
    # this is how I made the cohort from Will's 3 model groups...
    # it's slow(er) so I did it and let it commit

    my @groups = Genome::ModelGroup->get([13391, 13392, 13411]);
    is(scalar(@groups), 3, "got 3 members");

    my @samples = map { $_->subjects(-hints => [qw/attributes/]) } @groups;
    ok(scalar(@samples), "got " . scalar(@samples) . " samples");

    my @patients = Genome::Individual->get(id => [ map { $_->source_id } @samples ], -hints => [qw/attributes/]);
    ok(scalar(@patients), "got " . scalar(@patients) . " patients");

    $asms_cohort = Genome::PopulationGroup->create(
        id => -1000,
        name => 'ASMS-cohort-TGI-2011',
        members => \@patients,
    );
    ok($asms_cohort, "created the ASMS cohort");
}

# now we do everything just in memory since we're just experimenting...

my @members = $asms_cohort->members();
is(scalar(@members), 304, "got the expected number of patients");

my $p = Genome::ProcessingProfile::PhenotypeCorrelation->create(
    id                              => -10001,
    name                            => 'TESTSUITE Quantitative Population Phenotype Correlation',
    alignment_strategy              => 'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29',
    snv_detection_strategy          => 'samtools r599 filtered by snp-filter v1',
    indel_detection_strategy        => 'samtools r599 filtered by indel-filter v1',
    #sv_detection_strategy           => undef, 
    #cnv_detection_strategy          => undef,
    group_samples_for_genotyping_by => 'test_nomenclature.foo',
    phenotype_analysis_strategy     => 'quantitative',
);
ok($p, "created a processing profile") or diag(Genome::ProcessingProfile::PhenotypeCorrelation->error_message);

my $m = $p->add_model(
    name    => 'TESTSUITE-ASMS-test1',
    subclass_name => 'Genome::Model::PhenotypeCorrelation',
    subject => $asms_cohort,
);
ok($m, "created a model") or diag(Genome::Model->error_message);

my $i1 = $m->add_input(
    name => 'reference_sequence_build',
    value => Genome::Model::Build->get('106942997'),
);
ok($i1, "add a reference sequence build to it");

my $asms_target_region_set_name = 'Freimer Pool of original (4k001L) plus gapfill (4k0026)';
my $i2 = $m->add_input(
    name => 'target_region_set_name',
    value => UR::Value->get($asms_target_region_set_name),
);

my @patients = $asms_cohort->members;
ok(scalar(@patients), scalar(@patients) . " patients");

my @samples = Genome::Sample->get(source_id => [ map { $_->id } @patients ]);
ok(scalar(@samples), scalar(@samples) . " samples");

my @i = Genome::InstrumentData::Solexa->get('sample_id' => [ map { $_->id } @samples ], target_region_set_name => $asms_target_region_set_name);
ok(scalar(@i), scalar(@i) . " instdata");

my @ii;
for my $i (@i) {
    my $ii = $m->add_input(
        name => 'instrument_data',
        value => $i
    );
    push @ii, $ii if $ii;
}
is(scalar(@ii), scalar(@i), "assigned " . scalar(@i) . " instrument data");

my $b = $m->add_build(
    subclass_name => 'Genome::Model::Build::PhenotypeCorrelation',
    data_directory => "/tmp/foo"
);
ok($b, "created a build") or diag(Genome::Model->error_message);

# we would normally do $build->start() but this is easier to debug minus workflow guts...
#$b->start(
#    server_dispatch => 'inline',
#    job_dispatch    => 'inline',
#);
#is($b->status, 'Succeeded', "build succeeded!");

my $retval = eval { $p->_execute_build($b); };
is($retval, 1, 'execution of the build returned true');
is($@, '', 'no exceptions thrown during build process') or diag $@;

