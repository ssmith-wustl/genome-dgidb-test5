package Genome::Model::Tools::DetectVariants2::VarscanSomatic;

use strict;
use warnings;

use File::Copy;
use Genome;

class Genome::Model::Tools::DetectVariants2::VarscanSomatic {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has_optional => [
        detect_snvs => {
            default => '1',
        },
        detect_indels => {
            default => '1',
        },
        snv_params => {
            default => "--min-coverage 3 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1",
        },
        indel_params => {
            default => "--min-coverage 3 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1",
        },
    ],
    #This section hides those parameters that are unsupported from appearing in the help text
    has_constant_optional => [
        sv_params => {},
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

    my $snv_params = $self->snv_params || "";
    my $indel_params = $self->indel_params || "";
    my $result;
    if ( ($self->detect_snvs && $self->detect_indels) && ($snv_params eq $indel_params) ) {
        $result = $self->_run_varscan($output_snp, $output_indel, $snv_params);
    } else {
        # Run twice, since we have different parameters. Detect snps and throw away indels, then detect indels and throw away snps
        if ($self->detect_snvs && $self->detect_indels) {
            $self->status_message("Snp and indel params are different. Executing Varscan twice: once each for snps and indels with their respective parameters");
        }
        my ($temp_fh, $temp_name) = Genome::Sys->create_temp_file();

        if ($self->detect_snvs) {
            $result = $self->_run_varscan($output_snp, $temp_name, $snv_params);
        }
        if ($self->detect_indels) {
            if($self->detect_snvs and not $result) {
                $self->status_message('Varscan did not report success for snp detection. Skipping indel detection.')
            } else {
                $result = $self->_run_varscan($temp_name, $output_indel, $indel_params);
            }
        }
    }

    return $result;
}

sub _run_varscan {
    my $self = shift;
    my ($output_snp, $output_indel, $varscan_params) = @_;
    my $normal_bam = $self->control_aligned_reads_input;
    my $tumor_bam = $self->aligned_reads_input;
    my $reference = $self->reference_sequence_input;


    my $varscan = Genome::Model::Tools::Varscan::Somatic->create(
        normal_bam => $normal_bam,
        tumor_bam => $tumor_bam,
        reference => $reference,
        output_snp => $output_snp,
        output_indel => $output_indel,
        varscan_params => $varscan_params,
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

