#!/usr/bin/env perl
use above 'Genome';
use strict;
use warnings;
use Test::More tests => 6;

my $RUN = shift;

Genome::Model::ProteinAnnotation->class;
Genome::ProcessingProfile::ProteinAnnotation->class;

my $t = Genome::Taxon->get(name => 'Bifidobacterium breve DSM 20213');
ok($t, "got a taxon") or die;

note("gram_stain: " . $t->gram_stain);

my $p = Genome::ProcessingProfile::ProteinAnnotation->create(
    name => 'PAP Test 1',
    chunk_size => 10,
    annotation_strategy => 'psort-b union k-e-g-g-scan union inter-pro-scan',
);
ok($p, "made a processing profile") or die;


my $predicted_genes_file = __FILE__ . '.input.fa';
ok(-e $predicted_genes_file, 'found test file of gene predictions');


my $m = $p->add_model(
    name => 'PAP-test-model',
    subject => $t,
    processing_profile => $p,
    #prediction_fasta_file => UR::Value::FilePath->get($predicted_genes_file),
);
ok($m, "created a model") or die;

$m->prediction_fasta_file(UR::Value::Text->get($predicted_genes_file));
#print $m->prediction_fasta_file();


my $tmp = Genome::Sys->create_temp_directory("pap-test");
ok(-e $tmp, "found temp directory $tmp");

my $b = $m->add_build(
    data_directory => $tmp
);
ok($b, 'defined a build');

if (not $RUN or $RUN ne 'RUN') {
    note("NOT running the pipeline because RUN is not on the cmdline for this test");
    exit;
}

note("running the build...");

$b->start(server_dispatch => 'inline', job_dispatch => 'inline');



