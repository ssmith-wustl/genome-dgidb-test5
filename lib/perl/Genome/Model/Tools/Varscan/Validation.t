#!/gsc/bin/perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';

use Test::More tests => 7;

use_ok('Genome::Model::Tools::Varscan::Validation');

my $ref_seq = Genome::Model::Build::ImportedReferenceSequence->get_by_name('NCBI-human-build36');
isa_ok($ref_seq, 'Genome::Model::Build::ImportedReferenceSequence', 'loaded reference sequence');

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Varscan-Validation';

my $tumor_bam =  join('/', $test_data_dir, 'tumor.tiny.bam');
my $normal_bam = join('/', $test_data_dir, 'normal.tiny.bam');

my $expected_result_dir = join('/', $test_data_dir, '1');

my $expected_snp_file = join('/', $expected_result_dir, 'varscan.snp');
my $expected_indel_file = join('/', $expected_result_dir, 'varscan.indel');
my $expected_validation_file = join('/', $expected_result_dir, 'varscan.snp.validation');

my $tmpdir = File::Temp::tempdir('VarscanValidationXXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $output_snp = join('/', $tmpdir, 'varscan.snp');
my $output_indel = join('/', $tmpdir, 'varscan.indel');
my $output_validation = join('/', $tmpdir, 'varscan.validation');

my $varscan_command = Genome::Model::Tools::Varscan::Validation->create(
    output_snp => $output_snp,
    output_indel => $output_indel,
    output_validation => $output_validation,
    tumor_bam => $tumor_bam,
    normal_bam => $normal_bam,
    reference => $ref_seq->fasta_file,
    samtools_version => 'r599',
    varscan_params => '--min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.01 --validation 1 --min-coverage 8',
);

isa_ok($varscan_command, 'Genome::Model::Tools::Varscan::Validation', 'created validation command');
ok($varscan_command->execute, 'executed varscan validation');

my $snp_diff = Genome::Utility::FileSystem->diff_file_vs_file($output_snp, $expected_snp_file);
ok(!$snp_diff, 'snp output matches expected result')
    or diag("Diff:\n" . $snp_diff);

my $indel_diff = Genome::Utility::FileSystem->diff_file_vs_file($output_indel, $expected_indel_file);
ok(!$indel_diff, 'indel output matches expected result')
    or diag("Diff:\n" . $indel_diff);
    
my $validation_diff = Genome::Utility::FileSystem->diff_file_vs_file($output_validation, $expected_validation_file);
ok(!$validation_diff, 'validation output matches expected result')
    or diag("Diff:\n" . $validation_diff);
