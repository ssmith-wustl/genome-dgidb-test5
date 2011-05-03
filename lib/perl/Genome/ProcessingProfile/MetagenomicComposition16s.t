#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::ProcessingProfile::MetagenomicComposition16s') or die;

my $pp = Genome::ProcessingProfile->create(
    type_name => 'metagenomic composition 16s',
    name => '16S Test Sanger',
    amplicon_size => 1150,
    sequencing_center => 'gsc',
    sequencing_platform => 'sanger',
    assembler => 'phred_phrap',
    assembler_params => '-vector_bound 0 -trim_qual 0',
    trimmer => 'finishing',
    classifier => 'kroyer',
    classifier_params => '-training_set broad',
);
ok($pp, 'create pp') or die;
isa_ok($pp, 'Genome::ProcessingProfile::MetagenomicComposition16s');

my %assembler_params = $pp->assembler_params_as_hash;
is_deeply(
    \%assembler_params,
    { vector_bound => 0, trim_qual => 0 },
    'assembler params as hash'
);

my %trimmer_params = $pp->trimmer_params_as_hash;
is_deeply(
    \%trimmer_params,
    {},
    'trimmer params as hash'
);

my %classifier_params = $pp->classifier_params_as_hash;
is_deeply(
    \%classifier_params,
    { training_set => 'broad' },
    'classifier params as hash'
);

my @stages = $pp->stages;
is_deeply(\@stages, [qw/ one /], 'Stages');
my @stage_one_classes = $pp->classes_for_stage($stages[0]);
is_deeply(
    \@stage_one_classes, 
    [qw/
    Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::Sanger
    Genome::Model::Event::Build::MetagenomicComposition16s::Classify
    Genome::Model::Event::Build::MetagenomicComposition16s::Orient
    Genome::Model::Event::Build::MetagenomicComposition16s::Reports
    Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp
    /], 
    'Stage one classes'
);

done_testing();
exit;

