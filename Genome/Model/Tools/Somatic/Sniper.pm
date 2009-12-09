package Genome::Model::Tools::Somatic::Sniper;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::Sniper {
    is => ['Command','Genome::Software'],
    has => [
        tumor_bam_file => { 
            is  => 'String',
            is_input=>1, 
            doc => 'The input tumor BAM file.',
        },
        normal_bam_file => { 
            is  => 'String',
            is_input=>1, 
            doc => 'The input normal BAM file.',
        },
        output_snp_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper SNP output file.',
        },
        output_indel_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper indel output file.',
        },
        quality_filter => {
            is => 'Integer',
            is_input=>1,
            is_optional=>1, 
            doc=>'minimum somatic quality to include in the snp output. default is 15.',
            default=>15,
        },
        reference_file => {
            is  => 'String',
            is_input=>1,
            is_optional=>1, 
           default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa', 
            doc => 'The somatic sniper reference file',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
        },
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        }, 
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 1,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
    ],
};

sub help_brief {
    "Produces a list of high confidence somatic snps.";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt somatic sniper -tumor tumor.bam -normal normal.bam --output-snp-file snps.out --output-indel-file indels.out
gmt somatic sniper -tumor tumor.bam -normal normal.bam --output-snp-file snps.out --output-indel-file indels.out -q 10
EOS
}

sub help_detail {                           
    return <<EOS 
    Provide a tumor and normal BAM file and get a list of somatic snps.  
EOS
}

my $error_fh;

sub resolve_software_version{
    my $self = shift;
    return 'test';
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    # Skip if both output files exist... not sure if this should be here or not
    if (($self->skip_if_output_present)&&(-s $self->output_snp_file)&&(-s $self->output_indel_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    $self->status_message("beginning execute");
    
    # Validate files
    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->tumor_bam_file) ) {
        $self->error_message("Could not validate tumor file:  ".$self->tumor_bam_file );
        die;
    } 

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->normal_bam_file) ) {
        $self->error_message("Could not validate normal file:  ".$self->normal_bam_file );
        die;
    } 

    # Run sniper C program
    my $cmd = "bam-somaticsniper -Q " . $self->quality_filter. " -f ".$self->reference_file." ".$self->tumor_bam_file." ".$self->normal_bam_file ." " . $self->output_snp_file . " " . $self->output_indel_file; 
    my $result = Genome::Utility::FileSystem->shellcmd( cmd=>$cmd, input_files=>[$self->tumor_bam_file,$self->normal_bam_file], output_files=>[$self->output_snp_file,$self->output_indel_file], skip_if_output_is_present=>0 );

    $self->status_message("ending execute");
    return $result; 
}

1;
