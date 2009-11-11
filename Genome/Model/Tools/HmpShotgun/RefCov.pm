package Genome::Model::Tools::HmpShotgun::RefCov;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::HmpShotgun::RefCov {
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
        stats_file => {
        	    is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'The resulting alignment.',
        },
        
	],
    has_param => [
           lsf_resource => {
           default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=4000]',
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
    $self->status_message(">>>Running HMP RefCov at ".UR::Time->now);
    #my $model_id = $self->model_id;
    $self->status_message("Aligned Bam File: ".$self->aligned_bam_file);
    $self->status_message("Regions file: ".$self->regions_file);
    
    my $stats_file = $self->working_directory."/reports/refcov_stats.txt";
    $self->stats_file($stats_file);
    my @expected_output_files = ($stats_file);
    
    $self->status_message("Output stats file: ".$stats_file);
    
    my $rv_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_output_files);
    if ($rv_check) {
    	$self->status_message("Expected output files exist.  Skipping processing.");
    	$self->status_message("<<<Completed RefCov at ".UR::Time->now);
    	return 1;
    }
 
    unless (-e $self->working_directory) {
    	Genome::Utility::FileSystem->create_directory($self->working_directory);
    }
   
    my $cmd = "/gscuser/jwalker/svn/TechD/RefCov/bin/refcov-64.pl ".$self->aligned_bam_file." ".$self->regions_file." ".$stats_file;    
     														
    $self->status_message("Running report at ".UR::Time->now);
    my $rv = Genome::Utility::FileSystem->shellcmd(cmd=>$cmd);
    
    if ($rv == 1) {
    	Genome::Utility::FileSystem->mark_files_ok(input_files=>\@expected_output_files);
    }
    
    $self->status_message("<<<Completed RefCov at ".UR::Time->now);
    
    return 1;
}
1;
