#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
require File::Compare;

use Cwd;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);

ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

# FIXME link needed files!
my $example_fastq = Genome::Model::DeNovoAssembly::Test->example_fastq_file_for_model($model);
symlink($example_fastq, $build->collated_fastq_file);
ok(-s $build->collated_fastq_file, 'Linked fastq file') or die;

my $example_afg_file = Genome::Model::DeNovoAssembly::Test->example_assembly_afg_file_for_model($model);
symlink($example_afg_file, $build->assembly_afg_file);
ok(-s $build->assembly_afg_file, 'Linked assembly afg file') or die;

my $example_sequences_file = Genome::Model::DeNovoAssembly::Test->example_sequences_file_for_model($model);
symlink($example_sequences_file, $build->sequences_file);
ok(-s $build->sequences_file, 'Linked sequences file') or die;

my $example_contigs_fasta_file = Genome::Model::DeNovoAssembly::Test->example_sequences_file_for_model($model);
symlink($example_contigs_fasta_file, $build->contigs_fasta_file);
ok(-s $build->contigs_fasta_file, 'Linked contigs.fa file') or die;

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet->create( build_id => $build->id);
ok($velvet, 'Created post assemble velvet');

#velvet_asm.afg file should not exist
ok($velvet->execute, 'Execute post assemble velvet');

# TODO make sure it worked!

#TODO make accessor methods of each of these??

#TODO - ace files do not match because phd time stamp will be different

my @file_names_to_test = qw/ reads.placed readinfo.txt
                        gap.txt contigs.quals contigs.bases
                        supercontigs.fasta supercontigs.agp stats.txt
                         /;

#skipping input fasta.gz and qual.gz files for now

my $test_data_dir = '/gscmnt/sata420/info/testsuite_data/Genome-Model/DeNovoAssembly/velvet_solexa_build_post_assemble/edit_dir';

foreach my $file (@file_names_to_test) {
    ok(-e $test_data_dir."/$file", "Test data dir $file file exists");
    ok(-e $build->data_directory."/edit_dir/$file", "Tmp test dir $file file exists");
    ok(File::Compare::compare($build->data_directory."/edit_dir/$file", $test_data_dir."/$file") == 0, "$file files match");
}

#TODO - this is bit of a hack but test can't clean itself up because it's running in the /tmp dir
#ok(system("chdir $test_data_dir") == 1, "Switched back to test data_dir");

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
