package Genome::Model::Tools::MetagenomicCompositionShotgun::RefCov;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::MetagenomicCompositionShotgun::RefCov {
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
        read_count_file => {
        	is  => 'String',
                is_input => '1',
                doc => 'The reads/contig summary.',
        },
        combined_file => {
                is  => 'String',
                is_output => '1',
                is_optional => '1',
                doc => 'The resulting alignment.',
        },
        lsf_resource => {
                is_param => 1,
                value => "-R 'select[mem>4000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=4000]' -M 4000000",
                #default_value => "-R 'select[mem>30000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=30000]' -M 30000000",
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
    $self->status_message("Read count file: ".$self->read_count_file);
    
    #$self->status_message("<<<Completed HMP RefCov for testing at ".UR::Time->now);
    #return 1;
    
    #expected output files
    my $stats_file = $self->working_directory."/reports/refcov_stats.txt";
    
    my $readcount_file = $self->read_count_file;
    my $combined_file = $self->working_directory."/reports/combined_refcov.txt";
    
    $self->combined_file($combined_file);
    
    my @expected_refcov_output_files = ($stats_file);
    
    $self->status_message("Output stats file: ".$stats_file);
    
    my $rv_check = Genome::Sys->are_files_ok(input_files=>\@expected_refcov_output_files);
    if ($rv_check) {
    	$self->status_message("Expected output files exist.  Skipping generation of ref cov stats file.");
    } else {
    
        my $cmd = Genome::Model::Tools::MetagenomicCompositionShotgun::ParallelRefCov->create(aligned_bam_file=>$self->aligned_bam_file, regions_file=>$self->regions_file, report_file=>$stats_file, working_directory=>$self->working_directory);	
													
    	$self->status_message("Running ref cov report at ".UR::Time->now);
    	#my $rv = Genome::Sys->shellcmd(cmd=>$cmd);
    	my $rv = $cmd->execute;
    	if ($rv == 1) {
    		Genome::Sys->mark_files_ok(input_files=>\@expected_refcov_output_files);
    	}
    	$self->status_message("RefCov file generated at ".UR::Time->now);
    }
    	
    my @expected_output_files = ($combined_file);
    my $rv_output_check = Genome::Sys->are_files_ok(input_files=>\@expected_output_files);
    #The re-check of the ref cov check value (rv_check) is necessary because if the refcov stats file has been regenerated,
    #then the subsequent report files should be regenerated.
    if ($rv_output_check && $rv_check) {
   		$self->status_message("Expected output files exist.  Skipping generation of the combined file.");
   		$self->status_message("<<<Completed RefCov at ".UR::Time->now);
   		return 1;
    } else {
    	$self->status_message("The previous ref cov stats file may have been regenerated.  Attempting to explicitly delete: $combined_file" );
    	unlink($combined_file);
    }
    
    $self->status_message("Now combining ref cov stats at ".UR::Time->now);
    
    my $taxonomy_file = "/gscmnt/sata409/research/mmitreva/databases/Bact_Arch_Euky.taxonomy.txt";
    my $viral_headers_file = "/gscmnt/sata421/research/mmitreva/adukes/viruses_nuc.updated.len_50.fasta.headers";
    
    my $combine = Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovCombine->create(
        refcov_output_file => $stats_file,
        reference_counts_file => $readcount_file,
        taxonomy_file =>  $taxonomy_file,
        viral_headers_file => $viral_headers_file,
        output => $combined_file,
    );
    $self->status_message(Data::Dumper::Dumper $combine);
    my $rv_combine = eval{$combine->execute};
    unless($rv_combine){
        $self->error_message("Failed to execute RefCovCombine! $@");
        return;
    }
    
    $self->status_message("Done combining ref cov stats with read counts at ".UR::Time->now);
    
    if ($rv_combine) {
    	Genome::Sys->mark_files_ok(input_files=>\@expected_output_files);
        $self->combined_file($combined_file);
    }
    
    $self->status_message("<<<Completed RefCov at ".UR::Time->now);
    
    return 1;
}
1;
