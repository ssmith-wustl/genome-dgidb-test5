#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);

ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

my $example_fastq = Genome::Model::DeNovoAssembly::Test->example_fastq_file_for_model($model);

symlink($example_fastq, $build->collated_fastq_file);
ok(-s $build->collated_fastq_file, 'Linked fastq file') or die;

my $example_afg_file = Genome::Model::DeNovoAssembly::Test->example_assembly_afg_file_for_model($model);
symlink($example_afg_file, $build->assembly_afg_file);
ok(-s $build->assembly_afg_file, 'Linked assembly afg file') or die;

my $example_sequences_file = Genome::Model::DeNovoAssembly::Test->example_sequences_file_for_model($model);
symlink($example_sequences_file, $build->sequences_file);
ok(-s $build->sequences_file, 'Linked sequences file') or die;

my $example_contigs_fasta_file = Genome::Model::DeNovoAssembly::Test->example_contigs_fasta_file_for_model($model);
symlink($example_contigs_fasta_file, $build->contigs_fasta_file);
ok(-s $build->contigs_fasta_file, 'Linked contigs.fa file') or die;

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet->create( build_id => $build->id);
ok($velvet, 'Created post assemble velvet');

ok($velvet->execute, 'Execute post assemble velvet');

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model/DeNovoAssembly/velvet_solexa_build_post_assemble/edit_dir';

my @file_names_to_test = qw/ reads.placed readinfo.txt
                        gap.txt contigs.quals contigs.bases
                        supercontigs.fasta supercontigs.agp stats.txt
                         /;

foreach my $file (@file_names_to_test) {
    my $data_directory = $build->data_directory;
    ok(-e $test_data_dir."/$file", "Test data dir $file file exists");
    ok(-e $data_directory."/edit_dir/$file", "Tmp test dir $file file exists");
    ok(File::Compare::compare($data_directory."/edit_dir/$file", $test_data_dir."/$file") == 0, "$file files match")
        or diag("Failed to compare $data_directory/edit_dir/$file with $test_data_dir/$file");
}

#test zipped files
foreach ('collated.fasta.gz', 'collated.fasta.qual.gz') {
    my $test_file = $test_data_dir."/$_";
    my $temp_file = $build->data_directory."/edit_dir/$_";

    ok(-e $test_file, "Test data dir $_ file exists");
    ok(-s $temp_file, "Tmp test dire $_ file exists");
    
    my @diff = `zdiff $test_file $temp_file`;
    is(scalar (@diff), 0, "Zipped $_ file matches");
}

#print $build->data_directory."\n";<STDIN>;

done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
