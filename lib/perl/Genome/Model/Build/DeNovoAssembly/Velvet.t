#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Build::DeNovoAssembly::Velvet') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_velvet;
ok($model, 'Got de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($build, 'Got example de novo assembly build') or die;
isa_ok($build, 'Genome::Model::Build::DeNovoAssembly::Velvet');

# file in main dir
_test_files_and_values(
    $build->data_directory,
    collated_fastq_file => 'collated.fastq',
    assembly_afg_file => 'velvet_asm.afg',
    contigs_fasta_file => 'contigs.fa',
    sequences_file => 'Sequences',
);

# files in edit dir
my $edit_dir = $build->edit_dir;
is($edit_dir, $build->data_directory.'/edit_dir', 'edit_dir');
_test_files_and_values(
    $edit_dir,
    ace_file => 'velvet_asm.ace',
    gap_file => 'gap.txt',
    contigs_bases_file => 'contigs.bases',
    contigs_quals_file => 'contigs.quals',
    read_info_file => 'readinfo.txt',
    reads_placed_file => 'reads.placed',
    assembly_fasta_file => 'contigs.bases',
    supercontigs_agp_file => 'supercontigs.agp',
    supercontigs_fasta_file => 'supercontigs.fasta',
    stats_file => 'stats.txt',
);

# metrics
my %metrics = $build->set_metrics;
#print Dumper(\%metrics);
my $expected_metrics = {
    'reads_processed_success' => '0.833',
    'reads_not_assembled_pct' => '0.702',
    'supercontigs' => '2424',
    'average_supercontig_length' => '146',
    'reads_assembled_success' => '0.298',
    'reads_assembled' => '7459',
    'contigs' => '2424',
    'average_read_length' => '90',
    'average_contig_length' => '146',
    'n50_supercontig_length' => '141',
    'reads_processed' => '25000',
    'assembly_length' => '354779',
    'reads_attempted' => '30000',
    'n50_contig_length' => '141',
    #these values are zero bec there are no contigs or supercontigs > 500 bp this test set
    'major_contig_length' => '500',
    'n50_contig_length_gt_500' => '0',
    'average_contig_length_gt_500' => '0',
    'n50_supercontig_length_gt_500' => '0',
    'average_supercontig_length_gt_500' => '0',
    'read_depths_ge_5x' => '1.1',
    'average_insert_size_used' => '260',
    'genome_size_used' => '4500000',
    'assembler_kmer_used' => 35,
};
is_deeply(\%metrics, $expected_metrics, 'metrics match');
for my $name ( keys %metrics ) {
    is($build->$name, $metrics{$name}, "set $name metric");
}
#old
my %old_to_new_metrics = (
    total_contig_number => 'contigs',
    #n50_contig_length => 'median_contig_length',
    total_supercontig_number => 'supercontigs',
    #n50_supercontig_length => 'median_supercontig_length',
    total_input_reads => 'reads_processed',
    placed_reads => 'reads_assembled',
    chaff_rate => 'reads_not_assembled_pct',
    total_contig_bases => 'assembly_length',
);
for my $old ( keys %old_to_new_metrics ) {
    my $new = $old_to_new_metrics{$old};
    is($build->$old, $build->$new, "$old matches $new");
}

done_testing();
exit;

sub _test_files_and_values {
    my ($dir, %files_and_values) = @_;

    for my $file ( keys %files_and_values ) {
        my $value = $build->$file or die;
        is($value, $dir.'/'.$files_and_values{$file}, $file);
        ok(-e $value, "$file exists");
    }

    return 1;
}

