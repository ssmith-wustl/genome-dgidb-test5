#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;

my $machine_hardware = `uname -m`;
like($machine_hardware, qr/x86_64/, 'on 64 bit machine') or die;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Assemble') or die;

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, "Got de novo assembly model") or die;
my $build = Genome::Model::Build->create(
    model => $model
);
ok($build, "Got de novo assembly build") or die;
ok($build->get_or_create_data_directory, 'resolved data dir');
my $example_build = Genome::Model::DeNovoAssembly::Test->example_build_for_model($model);
ok($example_build, 'got example build') or die;

# link input fastq files
my @assembler_input_files = $example_build->existing_assembler_input_files;
for my $target ( @assembler_input_files ) {
    my $basename = File::Basename::basename($target);
    my $dest = $build->data_directory.'/'.$basename;
    symlink($target, $dest);
    ok(-s $dest, "linked $target to $dest");
}

# create
my $assemble = Genome::Model::Event::Build::DeNovoAssembly::Assemble->create(build_id => $build->id, model => $model);
ok( $assemble, "Created soap assemble");
$assemble->dump_status_messages(1);

# check config file w/ fragment data and default insert size
my @libraries = ( { fragment_fastq_file => 'fragment.fastq' } );
#my $config = $assemble->_get_config_for_libraries(@libraries);
#my $expected_config = <<CONFIG;
#max_rd_len=120
#[LIB]
#avg_ins=320
#reverse_seq=0
#asm_flags=3
#pair_num_cutoff=2
#map_len=60
#q=fragment.fastq
#CONFIG
#is($config, $expected_config, 'config for fragment file and default insert size');

# lsf params
my $lsf_params = $assemble->bsub_rusage;
diag($lsf_params);
my $queue = 'alignment';
$queue = 'alignment-pd' if (Genome::Config->should_use_alignment_pd);
is($lsf_params, "-q $queue -n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>30000] rusage[mem=30000]' -M 30000000", 'lsf params'); 
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
    #print 'ex: '.$example_file."\n";
    #print 'file: '.$file."\n\n";
}

#print $build->data_directory."\n"; <STDIN>;
done_testing();
exit;

