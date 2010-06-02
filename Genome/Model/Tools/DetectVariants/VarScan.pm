
package Genome::Model::Tools::DetectVariants::VarScan;

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::DetectVariants::VarScan {
    is => 'Genome::Model::Tools::DetectVariants',
    has => [
        reference_sequence_input => {
            default => "/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa",
        },
    ],
    has_optional => [
        snv_params => {
            default => '--min-var-freq 0.10 --p-value 0.10 --somatic-p-value 0.01',
        },
        indel_params => {
            default => '--min-var-freq 0.10 --p-value 0.10 --somatic-p-value 0.01',
        },
        detect_snvs => {
            default => '1',
        },
        detect_indels => {
            default => '1',
        },
    ],
    has_constant => [
        snp_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/snps_all_sequences' },
        },
        filtered_snp_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/filtered.indelpe.snps' },
        },
        indel_output => {
            calculate_from => ["working_directory"],
            calculate => q{ $working_directory . '/indels_all_sequences' },
        },
        filtered_indel_output => {
            calculate_from => ["indel_output"],
            calculate => q{ $indel_output. '.filtered'},
        },
    ],
   
    has_optional => [
        detect_snvs => {
            default => 1,
        },
        detect_indels => {
            default => 1,
        },
    ],

    has_param => [
        lsf_resource => {
            default => "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=16000]' -M 1610612736",
        }
    ],
    has_constant_optional => [
        sv_params=>{},
    ],
};

sub help_brief {
    "Use VarScan for variant detection.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants var-scan --aligned_reads_input input.bam --reference_sequence_input reference.fa --working-directory ~/example/
EOS
}

sub help_detail {
    return <<EOS 
This tool runs VarScan for detection of SNPs and/or indels.
EOS
}

sub execute {
    my $self = shift;

    # ensure the reference sequence exists.
    my $reference = $self->reference_sequence_input;
    unless(Genome::Utility::FileSystem->check_for_path_existence($reference)) {
        $self->error_message("reference sequence file $reference does not exist");
        return;
    }

    # Create the working directory
    my $working_directory = $self->working_directory;
    unless (-d $working_directory) {
        eval {
            Genome::Utility::FileSystem->create_directory($working_directory);
        };
        
        if($@) {
            $self->error_message($@);
            return;
        }

        $self->status_message("Created directory: $working_directory");
        chmod 02775, $working_directory;
    }

    ## Get required parameters ##
    my $bam_file = $self->aligned_reads_input;
    my $output_snp = $self->snp_output;
    my $output_snp_filtered = $self->filtered_snp_output;
    my $output_indel = $self->indel_output;
    my $output_indel_filtered = $self->filtered_indel_output;

    ## Get VarScan parameters ##
    unless(-e $bam_file) {
        $self->error_message("Specified BAM file doesn't exist!");
        die $self->error_message;
    }

    unless ($self->detect_snvs || $self->detect_indels) {
        $self->status_message("Both detect_snps and detect_indels are set to false. Skipping execution.");
        return 1;
    }

    my $snv_params = $self->snv_params || "";
    my $indel_params = $self->indel_params || "";
    my $result;
    if ( ($self->detect_snvs && $self->detect_indels) && ($snv_params eq $indel_params) ) {
        $result = $self->_run_varscan($reference, $bam_file, $output_snp, $output_snp_filtered, $output_indel, $output_indel_filtered, $snv_params);
    } else {
        # Run twice, since we have different parameters. Detect snps and throw away indels, then detect indels and throw away snps
        if ($self->detect_snps && $self->detect_indels) {
            $self->status_message("Snp and indel params are different. Executing VarScan twice: once each for snps and indels with their respective parameters");
        }
        my ($temp_fh, $temp_name) = Genome::Utility::FileSystem->create_temp_file();
        my ($filtered_temp_fh, $filtered_temp_name) = Genome::Utility::FileSystem->create_filtered_temp_file();

        if ($self->detect_snvs) {
            $result = $self->_run_varscan($reference, $bam_file, $output_snp, $output_snp_filtered, $temp_name, $filtered_temp_name, $snv_params);
        }
        if ($self->detect_indels) {
            if($self->detect_snvs and not $result) {
                $self->status_message('VarScan did not report success for snv detection. Skipping indel detection.')
            } else {
                $result = $self->_run_varscan($reference, $bam_file, $temp_name, $filtered_temp_name, $output_indel, $output_indel_filtered, $indel_params);
            }
        }
    }

    return $result;
}

sub _run_varscan {
    my $self = shift;
    my ($reference, $bam_file, $output_snp, $output_snp_filtered, $output_indel, $output_indel_filtered, $varscan_params) = @_;

    my $varscan = Genome::Model::Tools::Varscan::Germline->create(
        bam_file => $bam_file,
        reference => $reference,
        output_snp => $output_snp,
        output_snp_filtered => $output_snp_filtered,
        output_indel => $output_indel,
        output_indel_filtered => $output_indel_filtered,
        varscan_params => $varscan_params,
    );

    unless($varscan->execute()) {
        $self->error_message('Failed to execute VarScan: ' . $varscan->error_message);
        return;
    }

    return 1;
}

sub generate_metrics {
    my $self = shift;

    my $metrics = {};
    
    if($self->detect_snvs) {
        my $snp_count      = 0;
        
        my $snp_output = $self->snp_output;
        my $snp_fh = Genome::Utility::FileSystem->open_file_for_reading($snp_output);
        while (my $row = $snp_fh->getline) {
            $snp_count++;
        }
        $metrics->{'total_snp_count'} = $snp_count;
    }

    if($self->detect_indels) {
        my $indel_count    = 0;
        
        my $indel_output = $self->indel_output;
        my $indel_fh = Genome::Utility::FileSystem->open_file_for_reading($indel_output);
        while (my $row = $indel_fh->getline) {
            $indel_count++;
        }
        $metrics->{'total indel count'} = $indel_count;
    }

    return $metrics;
}

1;
