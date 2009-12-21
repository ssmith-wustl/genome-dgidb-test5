package Genome::Model::Tools::HmpShotgun::FilterResults;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::HmpShotgun::FilterResults {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'String',
            is_input => '1',
            doc => 'The working directory.',
        },
        reference1_top_hit_alignment_file => {
        	is  => 'String',
                is_input => '1',
                doc => 'Reads aligned to the first reference.',
        },
        reference2_top_hit_alignment_file => {
        	is  => 'String',
                is_input => '1',
                doc => 'Reads aligned to the second reference.',
        },
        paired_end1_concise_file => {
        	    is  => 'String',
                is_input => '1',
                doc => 'The conscise file of multiple hits.',
        },
        paired_end2_concise_file => {
        	    is  => 'String',
                is_input => '1',
                doc => 'The conscise file of multiple hits.',
        },
        taxonomy_file => {
        		is  => 'String',
                is_input => '1',
                doc => 'Taxonomy file.',
        },
        filtered_alignment_file => {
        	    is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'The resulting filtered alignment.',
        },
        read_count_file => {
        	    is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'a report file.',
        },
        other_hits_file => {
        	    is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'a report file.',
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
    $self->status_message(">>>Running FilterResults at ".UR::Time->now);
    #my $model_id = $self->model_id;
    $self->status_message("Aligned Bam File for refseq1: ".$self->reference1_top_hit_alignment_file);
    $self->status_message("Aligned Bam File for refseq2: ".$self->reference2_top_hit_alignment_file);
    
    $self->status_message("Paired end 1 concise file: ".$self->paired_end1_concise_file);
    $self->status_message("Paired end 2 concise file: ".$self->paired_end2_concise_file);
    
    $self->status_message("Taxonomy file: ".$self->taxonomy_file);
    
    my $working_directory = $self->working_directory."/alignments_filtered/";
    my $report_directory = $self->working_directory."/reports/";
    
    unless (-e $report_directory) {
    	Genome::Utility::FileSystem->create_directory($report_directory);
    }

    my $other_hits_file = $report_directory."/other_hits.txt";
    my $read_count_file = $report_directory."/reads_per_contig.txt";
    my $filtered_alignment_file = $working_directory."/combined.sam";
    
    my @expected_output_files = ($other_hits_file,$read_count_file,$filtered_alignment_file);
    
    my $rv_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_output_files);
    if ($rv_check) {
    	$self->status_message("Expected output files exist.  Skipping processing.");
    	$self->status_message("<<<Completed FilterResults at ".UR::Time->now);
    	return 1;
    }
 
   
    my $cmd = "sahar code";
     														
    $self->status_message("Running filter at ".UR::Time->now);
    #my $rv = Genome::Utility::FileSystem->shellcmd(cmd=>$cmd);
    
    
    $self->filtered_alignment_file("foo");
    $self->read_count_file("bar");
    $self->other_hits_file("boo");
    $self->status_message("<<<Completed FilterResults at ".UR::Time->now);
    
    return 1;
}

sub find_top_hit {
	my $self = shift;
	
	
	return 1;
}

1;
