#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

unless (`uname -a` =~ /x86_64/){
    die 'Must run on a 64 bit machine';
}

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Assemble::Velvet');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

# example build
my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;

my $example_fastq = $example_build->collated_fastq_file;
symlink($example_fastq, $build->collated_fastq_file);
ok(-s $build->collated_fastq_file, 'Linked fastq file') or die;

my $velvet = Genome::Model::Event::Build::DeNovoAssembly::Assemble::Velvet->create( build_id => $build->id);

ok($velvet, 'Created assemble velvet');
ok($velvet->execute, 'Execute assemble velvet');

for my $file_name (qw/ contigs_fasta_file sequences_file assembly_afg_file /) {
    my $file = $build->$file_name;
    ok(-s $file, "Build $file_name exists");
    my $example_file = $example_build->$file_name;
    ok(-s $example_file, "Example $file_name exists");
    is( File::Compare::compare($file, $example_file), 0, "Generated $file_name matches example file");
}

#print $build->data_directory."\n";<STDIN>;
done_testing();
exit;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/Build/DeNovoAssembly/PrepareInstrumentData.t $
#$Id: PrepareInstrumentData.t 45247 2009-03-31 18:33:23Z ebelter $
