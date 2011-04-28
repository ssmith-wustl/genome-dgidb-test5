package Genome::Model::Tools::DetectVariants2::VarscanSomatic;

use strict;
use warnings;

use File::Copy;
use Genome;

class Genome::Model::Tools::DetectVariants2::VarscanSomatic {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has_optional => [
        params => {
            default => "--min-coverage 3 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1",
        },
    ],
    doc => 'This tool is a wrapper around `gmt varscan somatic` to make it meet the API for variant detection in the reference alignment pipeline'
};


sub help_brief {
    "Run the Varscan somatic variant detection"
}

sub help_synopsis {
    return <<EOS
Runs Varscan from BAM files
EOS
}

sub help_detail {
    return <<EOS 

EOS
}

sub _detect_variants {
    my $self = shift;

    ## Get required parameters ##
    my $output_snp = $self->_temp_staging_directory."/snvs.hq";
    my $output_indel = $self->_temp_staging_directory."/indels.hq";

    my $varscan = Genome::Model::Tools::Varscan::Somatic->create(
        normal_bam => $self->control_aligned_reads_input,
        tumor_bam => $self->aligned_reads_input,,
        reference => $self->reference_sequence_input,
        output_snp => $output_snp,
        output_indel => $output_indel,
        varscan_params => $self->params,
        no_headers => 1,
    );

    unless($varscan->execute()) {
        $self->error_message('Failed to execute Varscan: ' . $varscan->error_message);
        return;
    }

    return 1;
}

sub has_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::Varscan->available_varscan_versions;
    for my $v (@versions){
        if($v eq $version){
            return 1;
        }
    }
    return 0;  
}   

1;

