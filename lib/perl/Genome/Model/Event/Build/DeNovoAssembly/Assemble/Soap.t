#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

my $machine_hardware = `uname -m`;
like($machine_hardware, qr/x86_64/, 'on 64 bit machine') or die;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap',
    );
ok($model, "Got mock test model") or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, "Got mock test buid") or die;

# example build
my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;

# link input fastq files
my $one_fastq = $example_build->end_one_fastq_file;
symlink($one_fastq, $build->end_one_fastq_file);
ok(-s $build->end_one_fastq_file, "Link $one_fastq") or die;

my $two_fastq = $example_build->end_two_fastq_file;
symlink($two_fastq, $build->end_two_fastq_file);
ok(-s $build->end_two_fastq_file, "Linked $two_fastq") or die;

# create
my $assemble = Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap->create(build_id => $build->id);
ok( $assemble, "Created soap assemble");

# lsf params
my $lsf_params = $assemble->bsub_rusage;
diag($lsf_params);
is($lsf_params, "-n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>30000] rusage[mem=30000]' -M 30000000", 'lsf params'); 
ok( $assemble->execute, "Executed soap assemble");

# check files
my @file_exts = qw/ contig         gapSeq        links     peGrads
                    preGraphBasic  readOnContig  scafSeq   updated.edge
                    ContigIndex    edge          kmerFreq  newContigIndex
                    preArc         readInGap     scaf      scaf_gap        
                    vertex
                    /;
foreach my $ext ( @file_exts ) {
    my $example_file = $example_build->soap_output_file_for_ext($ext);
    ok(-s $example_file, "Example $ext file exists");
    my $file = $build->soap_output_file_for_ext($ext);
    ok(-s $file, "$ext file exists");
    is(File::Compare::compare($example_file, $file), 0, "$ext files match");
}

#print $build->data_directory."\n"; <STDIN>;
done_testing();
exit;

