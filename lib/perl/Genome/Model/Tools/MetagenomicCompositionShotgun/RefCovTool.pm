package Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovTool;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovTool {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'String',
            is_input => '1',
            doc => 'The working directory.',
        },
        aligned_bam_file => {
        	is  => 'String',
                is_input => '1',
                doc => 'The reference sequence.',
        },
        regions_file => {
        	is  => 'String',
                is_input => '1',
                doc => 'The reads to align.',
        },
        report_file => {
        	is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'The reads to align.',
        },
        lsf_resource => {
                is_param => 1,
                value => "-R 'select[mem>10000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=10000]' -M 10000000",
        },
        
	],
};

sub help_brief {
    'Run the reference coverage report.';
}

sub help_detail {
    return <<EOS
    Runs the reference coverage report.
EOS
}

sub execute {
    my $self = shift;

    $self->dump_status_messages(1);
    
    $self->status_message(">>>Running HMP RefCovTool at ".UR::Time->now);
    $self->status_message("Aligned Bam File: ".$self->aligned_bam_file);
    $self->status_message("Regions file: ".$self->regions_file);
    
    #expected output files
    #my $stats_file = $self->working_directory."/reports/refcov_stats.txt";
    my ($basename,$dirname) = File::Basename::fileparse($self->regions_file);

    #put a tmp dir here
    my $stats_file = $self->working_directory."/report_".$basename;
    $self->report_file($stats_file);
    my @expected_refcov_output_files = ($stats_file);
    $self->status_message("Output stats file: ".$stats_file);

    my $cmd = "/gsc/bin/perl5.12.1 /gsc/var/tmp/Bio-SamTools/bin/refcov-64.pl ".$self->aligned_bam_file." ".$self->regions_file." ".$stats_file;    

    $self->status_message("Running ref cov report at ".UR::Time->now);
    my $rv = Genome::Sys->shellcmd(cmd=>$cmd);
    if ($rv == 1) {
        Genome::Sys->mark_files_ok(input_files=>\@expected_refcov_output_files);
    }else{
        $self->error_message("Failed to complete refcov!");
        die $self->error_message;
    }
    $self->status_message("RefCov file generated at ".UR::Time->now);

    $self->status_message("<<<Completed RefCov at ".UR::Time->now);

    return 1;
}
1;
