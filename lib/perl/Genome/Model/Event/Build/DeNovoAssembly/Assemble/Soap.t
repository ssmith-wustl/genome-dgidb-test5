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

#link input fastq files
my $one_fastq = Genome::Model::DeNovoAssembly::Test->example_end_one_fastq_file_for_model($model);
symlink($one_fastq, $build->end_one_fastq_file);
ok(-s $build->end_one_fastq_file, "Linked 1_fastq file");

my $two_fastq = Genome::Model::DeNovoAssembly::Test->example_end_two_fastq_file_for_model($model);
symlink($two_fastq, $build->end_two_fastq_file);
ok(-s $build->end_two_fastq_file, "Linked 2_fastq_file");

# create
my $assemble = Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap->create(build_id => $build->id);
ok( $assemble, "Created soap assemble");

# lsf params
my $assembler_params = $build->processing_profile->assembler_params;
# w/ cpus
$build->processing_profile->assembler_params('-cpus 4');
my $lsf_params = $assemble->bsub_rusage;
is($lsf_params, "-n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>30000] rusage[mem=30000]' -M 30000000", 'lsf params w/ 4 cpus'); 
$build->processing_profile->assembler_params($assembler_params);
$lsf_params = $assemble->bsub_rusage;
diag $lsf_params;
is($lsf_params, "-R 'span[hosts=1] select[type==LINUX64 && mem>30000] rusage[mem=30000]' -M 30000000", 'lsf params w/o cpus'); 

# execute
ok( $assemble->execute, "Executed soap assemble");

my @file_exts = qw/ contig         gapSeq        links     peGrads
                    preGraphBasic  readOnContig  scafSeq   updated.edge
                    ContigIndex    edge          kmerFreq  newContigIndex
                    preArc         readInGap     scaf      scaf_gap        vertex /;

my $example_dir = Genome::Model::DeNovoAssembly::Test->example_directory_for_model($model);

ok(-d $example_dir, "Solexa-soap example directory exists"); 

my $file_prefix = $build->instrument_data->sample_name.'_'.$build->center_name;

foreach (@file_exts) {
    ok(-e $example_dir."/$file_prefix".'.'.$_, "Example $_ file exists");
    ok(-e $build->data_directory."/$file_prefix".'.'.$_, "$_ file exists");
    ok(File::Compare::compare($example_dir."/$file_prefix".'.'.$_, $build->data_directory."/$file_prefix".'.'.$_) == 0, "$_ files match");
}

#<STDIN>;

done_testing();

exit;
