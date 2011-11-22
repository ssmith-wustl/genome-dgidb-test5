#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}

use_ok('Genome::Model::Build::DeNovoAssembly::Velvet') or die;

my $base_dir = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly';
my $archive_path = $base_dir.'/inst_data/-7777/archive.tgz';
ok(-s $archive_path, 'inst data archive path') or die;
my $example_version = '9';
my $example_dir = $base_dir.'/velvet_v'.$example_version;
ok(-d $example_dir, 'example dir') or die;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $taxon = Genome::Taxon->create(
    name => 'Escherichia coli TEST',
    domain => 'Bacteria',
    current_default_org_prefix => undef,
    estimated_genome_size => 4500000,
    current_genome_refseq_id => undef,
    ncbi_taxon_id => undef,
    ncbi_taxon_species_name => undef,
    species_latin_name => 'Escherichia coli',
    strain_name => 'TEST',
);
ok($taxon, 'taxon') or die;
my $sample = Genome::Sample->create(
    name => 'TEST-000',
    taxon_id => $taxon->id,
);
ok($sample, 'sample') or die;
my $library = Genome::Library->create(
    name => $sample->name.'-testlibs',
    sample_id => $sample->id,
    fragment_size_range => 260,
);
ok($library, 'library') or die;

my $instrument_data = Genome::InstrumentData::Solexa->create(
    id => -7777,
    sequencing_platform => 'solexa',
    read_length => 100,
    subset_name => '8-CGATGT',
    index_sequence => 'CGATGT',
    run_name => 'XXXXXX/8-CGATGT',
    run_type => 'Paired',
    flow_cell_id => 'XXXXXX',
    lane => 8,
    library => $library,
    archive_path => $archive_path,
    clusters => 15000,
    fwd_clusters => 15000,
    rev_clusters => 15000,
    analysis_software_version => 'not_old_iilumina',
);
ok($instrument_data, 'instrument data');
ok($instrument_data->is_paired_end, 'inst data is paired');
ok(-s $instrument_data->archive_path, 'inst data archive path');

my $pp = Genome::ProcessingProfile::DeNovoAssembly->create(
    name => 'De Novo Assembly Velvet Test',
    coverage => 0.5,#25000,
    read_processor => 'trim remove -length 10 | rename illumina-to-pcap',
    assembler_name => 'velvet one-button',
    assembler_version => '0.7.57-64',
    assembler_params => '-hash_sizes 31 33 35 -min_contig_length 100',
    post_assemble => 'standard-outputs -min_contig_length 50',
);
ok($pp, 'pp') or die;

my $model = Genome::Model::DeNovoAssembly->create(
    processing_profile => $pp,
    subject_name => $taxon->name,
    subject_type => 'species_name',
    center_name => 'WUGC',
);
ok($model, 'soap de novo model') or die;
ok($model->add_instrument_data($instrument_data), 'add inst data to model');

my $build = Genome::Model::Build::DeNovoAssembly->create(
    model => $model,
    data_directory => $tmpdir,
);
ok($build, 'created build');
my $example_build = Genome::Model::Build->create(
    model => $model,
    data_directory => $example_dir,
);
ok($example_build, 'create example build');

# MISC 
is($build->center_name, $build->model->center_name, 'center name');
is($build->genome_size, 4500000, 'Genome size');
is($build->calculate_average_insert_size, 260, 'average insert size');

# COVERAGE/KB USAGE
is($build->calculate_base_limit_from_coverage, 2_250_000, 'Calculated base limit');
is($build->calculate_estimated_kb_usage, (5_056_250), 'Kb usage based on coverage');
is($build->calculate_reads_attempted, (30000), 'Calculate reads attempted');
my $coverage = $model->processing_profile->coverage;
$pp->coverage(undef); #undef this to allow calc by proc reads coverage
is($build->calculate_estimated_kb_usage, (5_060_000), 'Kb usage w/o coverage');
$pp->coverage($coverage);

# PREPARE INST DATA
my @existing_assembler_input_files = $build->existing_assembler_input_files;
ok(!@existing_assembler_input_files, 'assembler input files do not exist');

my $prepare = Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData->create(build => $build, model => $model);
ok($prepare, 'create prepare instrument data');
$prepare->dump_status_messages(1);
ok($prepare->execute, 'execute prepare instrument data');

@existing_assembler_input_files = $build->existing_assembler_input_files;
is(@existing_assembler_input_files, 1, 'assembler input files exist');
my @example_existing_assembler_input_files = $example_build->existing_assembler_input_files;
is(@existing_assembler_input_files, 1, 'example assembler input files do not exist');
is(
    File::Compare::compare($existing_assembler_input_files[0], $example_existing_assembler_input_files[0]),
    0, 
    'assembler input file matches',
);

# ASSEMBLE
my $assembler_rusage = $build->assembler_rusage;
my $queue = ( $build->run_by eq 'apipe-tester' ) ? 'alignment-pd' : 'apipe';
is($assembler_rusage, "-q $queue -R 'select[type==LINUX64 && mem>30000] rusage[mem=30000] span[hosts=1]' -M 30000000", 'assembler rusage');
my %assembler_params = $build->assembler_params;
#print Data::Dumper::Dumper(\%assembler_params);
is_deeply(
    \%assembler_params,
    {
        'version' => '0.7.57-64',
        'min_contig_length' => '100',
        'file' => $existing_assembler_input_files[0],
        'ins_length' => '260',
        'hash_sizes' => [
        '31',
        '33',
        '35'
        ],
        'output_dir' => $build->data_directory,
        'genome_len' => '4500000'
    },
    'assembler params',
);

my $assemble = Genome::Model::Event::Build::DeNovoAssembly::Assemble->create(build => $build, model => $model);
ok($assemble, 'create assemble');
$assemble->dump_status_messages(1);
ok($assemble->execute, 'execute assemble');

for my $file_name (qw/ contigs_fasta_file sequences_file assembly_afg_file /) {
    my $file = $build->$file_name;
    ok(-s $file, "Build $file_name exists");
    my $example_file = $example_build->$file_name;
    ok(-s $example_file, "Example $file_name exists");
    is(File::Compare::compare($file, $example_file), 0, "Generated $file_name matches example file");
}

# POST ASSEMBLE
my $post_assemble = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble->create(build => $build, model => $model);
ok($post_assemble, 'Created post assemble velvet');
$post_assemble->dump_status_messages(1);
ok($post_assemble->execute, 'Execute post assemble velvet');

foreach my $file_name (qw/ 
    reads.placed readinfo.txt
    gap.txt contigs.quals contigs.bases
    reads.unplaced reads.unplaced.fasta
    supercontigs.fasta supercontigs.agp
    /) {
    my $example_file = $example_dir.'/edit_dir/'.$file_name;
    ok(-e $example_file, "$file_name example file exists");
    my $file = $build->data_directory.'/edit_dir/'.$file_name;
    ok(-e $file, "$file_name file exists");
    is(File::Compare::compare($file, $example_file), 0, "$file_name files match");
}

# METRICS TODO
my $metrics = Genome::Model::Event::Build::DeNovoAssembly::Report->create( build => $build, model => $model );
ok( $metrics, 'Created report' );
ok( $metrics->execute, 'Executed report' );
#check stats file
ok( -s $example_build->stats_file, 'Example build stats file exists' );
ok( -s $build->stats_file, 'Test created stats file' );
is(File::Compare::compare($example_build->stats_file,$build->stats_file), 0, 'Stats files match' );
#check build metrics
my %expected_metrics = (
    'n50_supercontig_length' => '141',
    'reads_processed_success' => '0.833',
    'reads_assembled_success' => '0.298',
    'reads_assembled' => '7459',
    'average_read_length' => '90',
    'reads_attempted' => 30000,
    'average_insert_size_used' => '260',
    'n50_contig_length' => '141',
    'genome_size_used' => '4500000',
    'reads_not_assembled_pct' => '0.702',
    'supercontigs' => '2424',
    'average_supercontig_length' => '146',
    'contigs' => '2424',
    'n50_supercontig_length_gt_500' => '0',
    'n50_contig_length_gt_500' => '0',
    'major_contig_length' => '500',
    'average_contig_length' => '146',
    'average_supercontig_length_gt_500' => '0',
    'average_contig_length_gt_500' => '0',
    'reads_processed' => '25000',
    'assembly_length' => '354779',
    'read_depths_ge_5x' => '1.1'
);
for my $metric_name ( keys %expected_metrics ) {
    ok( $expected_metrics{$metric_name} eq $build->$metric_name, "$metric_name metrics match" );
}

#print $build->data_directory."\n"; <STDIN>;

done_testing();
exit;

