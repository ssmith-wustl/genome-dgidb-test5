
package Genome::Model::Tools::DetectVariants::Somatic::VarScan;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants::Somatic::VarScan {
    is => ['Genome::Model::Tools::DetectVariants::Somatic'],
    has => [
        reference_sequence_input => {
            default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa",
        }
    ],
    has_constant => [
        snp_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/varscan.status.snp' },
        },
        indel_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/varscan.status.indel' },
        },
    ],
    has_optional => [
        detect_snps => {
            default => '1',
        },
        detect_indels => {
            default => '1',
        },
        snp_params => {
            default => "--min-coverage 3 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1",
        },
        indel_params => {
            default => "--min-coverage 3 --min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.05 --strand-filter 1",
        },
    ],

    has_param => [
        lsf_resource => {
            value => Genome::Model::Tools::Varscan::Somatic->__meta__->property('lsf_resource')->default_value,
        }
    ],

    #This section hides those parameters that are unsupported from appearing in the help text
    has_constant_optional => [
        sv_params => {},
    ],
    doc => 'This tool is a wrapper around `gmt varscan somatic` to make it meet the API for variant detection in the reference alignment pipeline'
};


sub help_brief {
    "Run the VarScan somatic variant detection"
}

sub help_synopsis {
    return <<EOS
Runs VarScan from BAM files
EOS
}

sub help_detail {
    return <<EOS 

EOS
}

sub execute {
    my $self = shift;

    ## Get required parameters ##
    my $normal_bam = $self->control_aligned_reads_input;
    my $tumor_bam = $self->aligned_reads_input;

    my $output_snp = $self->snp_output;
    my $output_indel = $self->indel_output;

    my $reference = $self->reference_sequence_input;

    unless(-e $normal_bam && -e $tumor_bam) {
        $self->error_message('One of the specified BAM files does not exist.');
        die $self->error_message;
    }

    unless ($self->detect_snps || $self->detect_indels) {
        $self->status_message("Both detect_snps and detect_indels are set to false. Skipping execution.");
        return 1;
    }

    my $snp_params = $self->snp_params || "";
    my $indel_params = $self->indel_params || "";
    my $result;
    if ( ($self->detect_snps && $self->detect_indels) && ($snp_params eq $indel_params) ) {
        $result = $self->_run_varscan($reference, $tumor_bam, $normal_bam, $output_snp, $output_indel, $snp_params);
    } else {
        # Run twice, since we have different parameters. Detect snps and throw away indels, then detect indels and throw away snps
        if ($self->detect_snps && $self->detect_indels) {
            $self->status_message("Snp and indel params are different. Executing VarScan twice: once each for snps and indels with their respective parameters");
        }
        my ($temp_fh, $temp_name) = Genome::Utility::FileSystem->create_temp_file();

        if ($self->detect_snps) {
            $result = $self->_run_varscan($reference, $tumor_bam, $normal_bam, $output_snp, $temp_name, $snp_params);
        }
        if ($self->detect_indels) {
            if($self->detect_snps and not $result) {
                $self->status_message('VarScan did not report success for snp detection. Skipping indel detection.')
            } else {
                $result = $self->_run_varscan($reference, $tumor_bam, $normal_bam, $temp_name, $output_indel, $snp_params);
            }
        }
    }

    return $result;
}

sub _run_varscan {
    my $self = shift;
    my ($reference, $tumor_bam, $normal_bam, $output_snp, $output_indel, $varscan_params) = @_;

    my $varscan = Genome::Model::Tools::Varscan::Somatic->create(
        normal_bam => $normal_bam,
        tumor_bam => $tumor_bam,
        reference => $reference,
        output_snp => $output_snp,
        output_indel => $output_indel,
        varscan_params => $varscan_params,
    );

    unless($varscan->execute()) {
        $self->error_message('Failed to execute VarScan: ' . $varscan->error_message);
        return;
    }

    return 1;
}


1;

