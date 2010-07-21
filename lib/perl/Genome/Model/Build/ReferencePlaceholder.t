#!/usr/bin/env perl
use strict;
use warnings;

use above 'Genome';
use Test::More tests => 10;

my $BASE = Genome::Config->root_directory;

use_ok('Genome::Model::Build::ReferencePlaceholder');

my $model = Genome::Model::Build::ReferencePlaceholder->get('NCBI-human-build36');
unless ($model) {
    $model = Genome::Model::Build::ReferencePlaceholder->create(
                                                                name => 'NCBI-human-build36',
                                                                sample_type => 'genomic dna'
                                                            );
}

my $reference_sequence_path = $model->data_directory;
is($reference_sequence_path,"$BASE/reference_sequences/NCBI-human-build36",'got reference_sequence_path');

my $ref_seq_path   = $model->full_consensus_path('fa');
my $sam_faidx_path = $model->full_consensus_sam_index_path(Genome::Model::Tools::Sam->default_samtools_version);
is($sam_faidx_path, $ref_seq_path.'.fai', 'Got correct ref seq sam fasta index');

my @get_subreference_paths = sort $model->subreference_paths(reference_extension => 'bfa');
is(scalar(@get_subreference_paths),25,'got get_subreference_paths countn');
is(scalar($get_subreference_paths[23]),Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/Y.bfa','got correct get_subreference_paths value');

my @get_subreference_names = sort $model->subreference_names();
is($get_subreference_names[23],'Y','got get_subreference_names');


my $lims_model = Genome::Model::Build::ReferencePlaceholder->get('Illumina sequencing adaptor v1');
unless ($lims_model) {
    $lims_model = Genome::Model::Build::ReferencePlaceholder->create(name => 'Illumina sequencing adaptor v1');
}
isa_ok($lims_model,'Genome::Model::Build::ReferencePlaceholder');

my $lims_ref_seq_path = $lims_model->data_directory;
is($lims_model->data_directory,'/gsc/var/lib/reference/set/2774911462/maq_binary_fasta','got expected lims data directory for reference model');
is($lims_model->full_consensus_path,'/gsc/var/lib/reference/set/2774911462/maq_binary_fasta/ALL.bfa','got expected lims full consensus path');

###

$model->delete;
$model = Genome::Model::Build::ReferencePlaceholder->create(name => 'NCBI-mouse-build37');
my $seq_dict_file = $model->get_sequence_dictionary("sam","mouse","r104");
my $result = Genome::Config::reference_sequence_directory() . "/NCBI-mouse-build37/seqdict/seqdict.sam";
is($seq_dict_file, $result, 'got correct sequence dictionary.');

exit;

###

$model->delete;

$model = Genome::Model::Build::ReferencePlaceholder->create(name => 'NCBI-human-build36', sample_type => 'cdna');

$reference_sequence_path = $model->data_directory;
is($reference_sequence_path,"$BASE/reference_sequences/NCBI-human-build36",'got reference_sequence_path');

@get_subreference_paths = sort $model->subreference_paths(reference_extension => 'bfa');
is(scalar(@get_subreference_paths),25,'got get_subreference_paths countn');
is(scalar($get_subreference_paths[23]),Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/Y.bfa','got correct get_subreference_paths value');

@get_subreference_names = sort $model->subreference_names();
is($get_subreference_names[23],'Y','got get_subreference_names');


