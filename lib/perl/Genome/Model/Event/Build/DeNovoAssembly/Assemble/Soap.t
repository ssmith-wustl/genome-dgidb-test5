#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

unless (`uname -a` =~ /x86_64/){
#    die 'Must run on a 64 bit machine';
}

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
is($lsf_params, "-n 4 -R 'select[type==LINUX64 && span[hosts=1] && mem>10000] rusage[mem=10000]' -M 10000000", 'lsf params w/ 4 cpus'); 
$build->processing_profile->assembler_params($assembler_params);
$lsf_params = $assemble->bsub_rusage;
is($lsf_params, "-R 'select[type==LINUX64 && span[hosts=1] && mem>10000] rusage[mem=10000]' -M 10000000", 'lsf params w/o cpus'); 

# execute
ok( $assemble->execute, "Executed soap assemble");

#check output files
my @files = qw/ Assembly.contig         Assembly.gapSeq        Assembly.links     Assembly.peGrads
                Assembly.preGraphBasic  Assembly.readOnContig  Assembly.scafSeq   Assembly.updated.edge
                Assembly.ContigIndex    Assembly.edge          Assembly.kmerFreq  Assembly.newContigIndex
                Assembly.preArc         Assembly.readInGap     Assembly.scaf      Assembly.scaf_gap  Assembly.vertex /;

my $example_dir = Genome::Model::DeNovoAssembly::Test->example_directory_for_model($model);

ok(-d $example_dir, "Solexa-soap example directory exists"); 

foreach (@files) {
    ok(-e $example_dir."/$_", "Example $_ file exists");
    ok(-e $build->data_directory."/$_", "$_ file created");
    ok(File::Compare::compare($example_dir."/$_", $build->data_directory."/$_") == 0, "$_ files match");
}

#print $example_dir.' '.$build->data_directory."\n";
#<STDIN>;

done_testing();

exit;
