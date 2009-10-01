package Genome::Model::Tools::Somatic::IndelpeRunner;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::IndelpeRunner {

    is  => ['Command'],
    has => [
       tumor_bam_file => {
            is       => 'String',
            is_input => '1',
            doc      => 'The bam file for tumor.',
        },
       ref_seq_file => {
            is       => 'String',
            is_input => '1',
            doc      => 'The refseq fa.',
        },
        output_dir => {
            is       => 'String',
            is_input => '1',
            doc      => 'The output directory.',
        },
        snp_output_file => {
            is       => 'String',
            is_optional => '1',
            doc      => 'The snp file produced in sam snpfilter... generated with the output dir if none is provided',
        },
        filtered_snp_file => {
            is       => 'String',
            is_optional => '1',
            is_output => '1',
            doc      => 'The filtered snp file produced in sam snpfilter... generated with the output dir if none is provided',
        },
        indel_output_file => {
            is       => 'String',
            is_optional => '1',
            doc      => 'The indel output file produced in sam snpfilter... generated with the output dir if none is provided',
        },
        filtered_indel_file => {
            is       => 'String',
            is_optional => '1',
            doc      => 'The filtered indel file produced in sam snpfilter... generated with the output dir if none is provided',
        },

       # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=2000] select[type==LINUX64 & mem > 2000] span[hosts=1]',
        },
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        } 
    ],
};

sub help_brief {
    return "Gets intersection of SNPs from somatic sniper and maq";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    gmt somatic snpfilter --sniper_snp_file=[pathname] --output_file=[pathname]
EOS
}

sub help_detail {                           
    return <<EOS 
    Calls `gmt snp intersect` on the tumor snp file from the last maq build and the snp file from somatic sniper.
    (Outputs lines from the somatic sniper file.)
EOS
}

sub execute {
    my ($self) = @_;
    $DB::single=1;

    my $tumor_bam_file = $self->tumor_bam_file();
    if ( ! Genome::Utility::FileSystem->validate_file_for_reading($tumor_bam_file) ) {
        die 'cant read from: ' . $tumor_bam_file;
    }

   
    #calling blank should return the $DEFAULT version in the G:M:T:Sam module
    my $sam_pathname = Genome::Model::Tools::Sam->path_for_samtools_version();

    # ensure the reference sequence exists.
    my $ref_seq_file = $self->ref_seq_file;
    # this might not work depending on your father and or grandfathers identity
    my $rv;
    
    my $analysis_base_path = $self->output_dir;
    unless (-d $analysis_base_path) {
        $rv = $self->create_directory($analysis_base_path);
        return unless $self->_check_rv("Failed to create directory: $analysis_base_path", $rv);
        chmod 02775, $analysis_base_path;
    }


     $rv = $self->check_for_existence($tumor_bam_file);
    return unless $self->_check_rv("Bam output file $tumor_bam_file was not found.", $rv);

    # Generate files not provided from data directory
    unless (defined $self->snp_output_file) {
        $self->snp_output_file($self->output_dir . "/tumor_snps_from_samtools");
    }
    unless (defined $self->filtered_snp_file) {
        $self->filtered_snp_file($self->output_dir . "/filtered_tumor_snps_from_samtools");
    }
    unless (defined $self->indel_output_file) {
        $self->indel_output_file($self->output_dir . "/tumor_indels");
    }
    unless (defined $self->filtered_indel_file) {
        $self->filtered_indel_file($self->output_dir . '/filtered_tumor_indels');
    }
    
    my $snp_output_file = $self->snp_output_file;
    my $filtered_snp_file = $self->filtered_snp_file;
    my $indel_output_file = $self->indel_output_file;
    my $filtered_indel_file = $self->filtered_indel_file;

    # Skip execution if the filtered_snp_file already exists. In the somatic pipeline, if we have models that already ran through analysis we should have this file. If we have imported bams this will need to run.
    if (-s $filtered_snp_file) {
        $self->status_message("Filtered snp file $filtered_snp_file already exists. Skipping execution");
        return 1;
    }



     # Remove the result files from any previous run
     #commented out the 'remove previous' from this standalone version
     #    unlink($snp_output_file, $filtered_snp_file, $indel_output_file, $filtered_indel_file);
 
    my $indel_finder_params = ('');

    my $samtools_cmd = "$sam_pathname pileup -c $indel_finder_params -f $ref_seq_file";

    #Originally "-S" was used as SNP calling. In r320wu1 version, "-v" is used to replace "-S" but with 
    #double indel lines embedded, this need sanitized
    #$rv = system "$samtools_cmd -S $tumor_bam_file > $snp_output_file"; 

    my $snp_cmd = "$samtools_cmd -v $tumor_bam_file > $snp_output_file";
    # Skip if we already have the output
    unless (-s $snp_output_file) {
        $rv = system $snp_cmd;  
        return unless $self->_check_rv("Running samtools SNP failed with exit code $rv\nCommand: $snp_cmd", $rv, 0);
    }

    my $snp_sanitizer = Genome::Model::Tools::Sam::SnpSanitizer->create(snp_file => $snp_output_file);
    $rv = $snp_sanitizer->execute;
    return unless $self->_check_rv("Running samtools snp-sanitizer failed with exit code $rv", $rv, 1);
    
    my $indel_cmd = "$samtools_cmd -i $tumor_bam_file > $indel_output_file";
    # Skip if we already have the output
    unless (-s $indel_output_file) {
        $rv = system $indel_cmd;
        return unless $self->_check_rv("Running samtools indel failed with exit code $rv\nCommand: $indel_cmd", $rv, 0);
    }

    #FIXME:8-25-09 i spoke to ben and varfilter is still too permissive to be trusted so just hardcode normal snpfilter
    #in somatic pipeline until we hear different
    my $filter_type =  'SnpFilter';

    if ($filter_type =~ /^VarFilter$/i) {
        my %params = (
            bam_file     => $tumor_bam_file,
            ref_seq_file => $ref_seq_file,
            filtered_snp_out_file   => $filtered_snp_file,
            filtered_indel_out_file => $filtered_indel_file,
        );
        $params{pileup_params} = $indel_finder_params if $indel_finder_params;
        
        my $varfilter = Genome::Model::Tools::Sam::VarFilter->create(%params);
        $rv = $varfilter->execute;
        return unless $self->_check_rv("Running samtools varFilter failed with exit code $rv", $rv, 1);
    }
    elsif ($filter_type =~ /^SnpFilter$/i) {
        # Skip if we already have the output
        unless (-s $filtered_indel_file) {
            my $indel_filter = Genome::Model::Tools::Sam::IndelFilter->create(indel_file => $indel_output_file, out_file => $filtered_indel_file);
            $rv = $indel_filter->execute;
            return unless $self->_check_rv("Running sam indel-filter failed with exit code $rv", $rv, 1);
        }
   
        my $snp_filter = Genome::Model::Tools::Sam::SnpFilter->create(
            snp_file   => $snp_output_file,
            out_file   => $filtered_snp_file,
            indel_file => $filtered_indel_file,
        );

        $rv = $snp_filter->execute;
        return unless $self->_check_rv("Running sam snp-filter failed with exit code $rv", $rv, 1);
        $self->filtered_snp_file($filtered_snp_file);
    }
    else {
        $self->error_message("Invalid variant filter type: $filter_type");
        die;
    }
} 
 
 sub _check_rv {
    my ($self, $msg, $rv, $cmp) = @_;

    if (defined $cmp) {
        return 1 if $rv == $cmp;
    }
    else {
        return $rv if $rv;
    }

    $self->error_message($msg);
    die;
}
    
sub check_for_existence {
    my ($self,$path,$attempts) = @_;

    unless (defined $attempts) {
        $attempts = 5;
    }

    my $try = 0;
    my $found = 0;
    while (!$found && $try < $attempts) {
        $found = -e $path;
        sleep(1);
        $try++;
        if ($found) {
            $self->status_message("existence check passed: $path");
            return $found;
        }
    }
    die;
}




1;
