package Genome::Model::Tools::DetectVariants::Maq;

#REVIEW fdu
#short:
#1. Fix help_synopsis
#2. replace lookup_iub_code with calling class method in Genome::Info::IUB
#3. replace generate_genotype_detail_file subroutine with G::M::T::Snp::GenotypeDetail
#4. Change to get reference_sequence via reference_build->full_consensus_path('bfa')
#5. No need to list working_directory, snp_output ... as properties
#and do calculation there. They should be moved down to the body of execute and 
#resolved their values there.
#
#Long:
#1. Currently, the snp and indel ouputs generated from this are not
#much useful to MG. The key file "filtered.indelpe.snps" is produced
#during the step of RunReports via calling '_snv_file_filtered' method
#od G::M::B::RefAlign::Solexa (check my review there), which makes no sense. That 
#chunk of codes should be moved from there to here and replace current varaint calling process.


use strict;
use warnings;

use Genome;

use File::Path;
use File::Temp;
use IO::File;

class Genome::Model::Tools::DetectVariants::Maq {
    is => ['Genome::Model::Tools::DetectVariants'],
    has => [
        snp_output => {
            doc => "",
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory .'/snps_all_sequences';
            |,
        },
        indel_output => {
            doc => "",
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory .'/indels_all_sequences';
            |,
        },
        pileup_output => {
            doc => "",
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory .'/pileup_all_sequences';
            |,
        },
        filtered_snp_output => {
            doc => "",
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory .'/filtered.indelpe.snps';
            |,
        },
        consensus_directory => {
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory .'/consensus';
            |,
        },
        consensus_output => {
            calculate_from => ['consensus_directory'],
            calculate      => q|
                return $consensus_directory . '/all_sequences.cns';
            |,
        },
        report_output => {
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory. '/report_input_all_sequences';
            |,
        },
        indelpe_output => {
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory. '/indelpe.out';
            |,
        },
        sorted_indelpe_output => {
            calculate_from => ['working_directory'],
            calculate      => q|
                return $working_directory. '/indelpe.sorted.out';
            |,
        },
    ],
    has_constant_optional => [
        sv_params => { },
    ],
};

sub help_brief {
    "Use maq for variant detection.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants maq --version 0.7.1 --aligned_reads_input input.map --reference_sequence_input reference.bfa --working-directory ~/example/
EOS
}

sub help_detail {
    return <<EOS 
This tool runs maq for detection of SNPs and/or indels.
EOS
}

sub execute {
    my $self = shift;

    unless ($self->detect_snps || $self->detect_indels) {
        $self->status_message("Both detect_snps and detect_indels are set to false. Skipping execution.");
        return 1;
    }

    my $snp_params = $self->snp_params || "";
    my $indel_params = $self->indel_params || "";
    my $genotyper_params;

    # make sure the params are the same, or we are only detecting one type of variant
    if ( ($self->detect_snps && $self->detect_indels) && ($snp_params ne $indel_params) ) {
        $self->status_message("Snp and indel params are different. This is not supported, as these parameters only affect the update genotype step");
        die;
    }
    if ($self->detect_snps) {
        $genotyper_params = $snp_params;
    } else {
        $genotyper_params = $indel_params;
    }

    my $ref_seq_file = $self->reference_sequence_input;
    unless(Genome::Utility::FileSystem->check_for_path_existence($ref_seq_file)) {
        $self->error_message("reference sequence file $ref_seq_file does not exist");
        return;
    }

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

    my $bam_file = $self->aligned_reads_input;
    unless(Genome::Utility::FileSystem->check_for_path_existence($bam_file)) {
        $self->error_message("Bam input file $bam_file was not found.");
        return;
    }

    my $snp_output = $self->snp_output;
    my $filtered_snp_output = $self->filtered_snp_output;
    my $indel_output = $self->indel_output;

    my $result;
    if ($self->detect_snps && $self->detect_indels) {
        $result = $self->_run_maq($snp_output, $filtered_snp_output, $indel_output, $genotyper_params);
    } else {
        # Run just snps or indels if we dont want both. Throw away the other type of variant
        my ($temp_fh, $temp_name) = Genome::Utility::FileSystem->create_temp_file();
        my ($filtered_temp_fh, $filtered_temp_name) = Genome::Utility::FileSystem->create_temp_file();

        if ($self->detect_snps) {
            $result = $self->_run_maq($snp_output, $filtered_snp_output, $temp_name, $genotyper_params);
        }
        if ($self->detect_indels) {
            $result = $self->_run_maq($temp_name, $filtered_temp_name, $indel_output, $genotyper_params);
        }
    }

    return $result;
}

sub _run_maq {
    my ($self, $snp_output, $filtered_snp_output, $indel_output, $genotyper_params) = @_;

    my $maq_pathname    = Genome::Model::Tools::Maq->path_for_maq_version($self->version);
    my $maq_pl_pathname = Genome::Model::Tools::Maq->proper_maq_pl_pathname($self->version);

    # ensure the reference sequence exists.
    my $reference_sequence = $self->reference_sequence_input;

    $self->update_genotype($genotyper_params);

    my $assembly_output = $self->consensus_output;
    unless ( Genome::Utility::FileSystem->check_for_path_existence($assembly_output) ) {
        $self->error_message("Assembly output file $assembly_output does not exist");
        return;
    }

    my $pileup_output = $self->pileup_output;
    my $accumulated_alignments = $self->aligned_reads_input;
    my $indelpe_output           = $self->indelpe_output;
    my $sorted_indelpe_output    = $self->sorted_indelpe_output;
    
    # Remove the result files from any previous run
    unlink ($snp_output, $filtered_snp_output, $indel_output, $pileup_output, $indelpe_output, $sorted_indelpe_output);

    my $cmd = "$maq_pathname cns2snp $assembly_output > $snp_output";
    unless (Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$assembly_output]) ) {
        $self->error_message("cns2snp.\ncmd: $cmd");
        return;
    }

    $cmd = "$maq_pathname indelsoa $reference_sequence $accumulated_alignments > $indel_output";
    unless (Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$reference_sequence, $accumulated_alignments]) ) {
        $self->error_message("indelsoa.\ncmd: $cmd");
        return;
    }

    my $filter = 'perl -nae '."'".'print if $F[2] =~ /^(\*|\+)$/'."'";
    $cmd = "$maq_pathname indelpe $reference_sequence $accumulated_alignments | $filter > $indelpe_output";
    unless (Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$reference_sequence, $accumulated_alignments]) ) {
        $self->error_message("indelpe.\ncmd: $cmd");
        return;
    }

    my $rv = Genome::Model::Tools::Snp::Sort->execute(
        snp_file    => $indelpe_output,
        output_file => $sorted_indelpe_output,
    );
    unless ($rv) {
        $self->error_message('Failed to run gmt snp sort');
        return;
    }
        
    my $indel_param;
    if (-s $sorted_indelpe_output) {
        $indel_param = "-F '$sorted_indelpe_output'";
    }
    else {
        $self->warning_message('Omitting indelpe data from the SNPfilter results because no indels were found');
        $indel_param = '';
    }

    $cmd = "$maq_pl_pathname SNPfilter $indel_param $snp_output > $filtered_snp_output";
    unless (Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$snp_output]) ) {
        $self->error_message("SNPfilter.\ncmd: $cmd");
        return;
    }
    
    # Running pileup requires some parsing of the snp file
    my $tmpfh = File::Temp->new();
    my $snp_fh = IO::File->new($snp_output);
    unless ($snp_fh) {
        $self->error_message("Can't open snp output file for reading: $!");
        return;
    }
    while(<$snp_fh>) {
        chomp;
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown) = split("\t");
        $tmpfh->print("$id\t$start\n");
    }
    $tmpfh->close();
    $snp_fh->close();

    $cmd = sprintf(
        "$maq_pathname pileup -v -l %s %s %s > %s",
        $tmpfh->filename,
        $reference_sequence,
        $accumulated_alignments,
        $pileup_output
    );
    unless (Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$tmpfh->filename, $reference_sequence, $accumulated_alignments]) ) {
        $self->error_message("pileup.\ncmd: $cmd");
        return;
    }

    unless ($self->generate_genotype_detail_file) {
        $self->error_message('Generating genotype detail file errored out');
        return;
    }

    return $self->verify_successful_completion;
}


sub verify_successful_completion {
    my $self = shift;

    for my $file ($self->snp_output, $self->pileup_output, $self->filtered_snp_output, $self->indel_output) {
        unless (-e $file) {
            $self->error_message("File $file doesn't exist or has no data");
            return;
        }
    }

    return 1;
}

sub generate_genotype_detail_file {
    my $self  = shift;

    my $snp_output    = $self->snp_output;
    my $pileup_output = $self->pileup_output;
    my $report_input_file = $self->report_output;

    for my $file ($snp_output, $pileup_output) {
        unless (-s $file) {
            $self->error_message("File $file dosen't exist or has no data");
            return;
        }
    }

    unlink $report_input_file if -e $report_input_file;
    my $report_fh = IO::File->new(">$report_input_file");
    
    my $snp_gd = Genome::Model::Tools::Snp::GenotypeDetail->create(
        snp_file   => $snp_output,
        out_file   => $report_input_file,
        snp_format => 'maq',
        maq_pileup_file => $pileup_output,
    );

    return $snp_gd->execute;
}

sub generate_metrics {
    my $self = shift;

    my $metrics = {};
    
    if($self->detect_snps) {
        my $snp_count      = 0;
        my $snp_count_good = 0;
        
        my $snp_output = $self->snp_output;
        my $snp_fh = Genome::Utility::FileSystem->open_file_for_reading($snp_output);
        while (my $row = $snp_fh->getline) {
            $snp_count++;
            my ($r,$p,$a1,$a2,$q,$c) = split /\s+/, $row;
            $snp_count_good++ if $q >= 15 and $c > 2;
        }
        
        $metrics->{'total_snp_count'} = $snp_count;
        $metrics->{'confident_snp_count'} = $snp_count_good;
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

sub update_genotype {
    my $self = shift;
    my $genotyper_params = shift;

    $DB::single = $DB::stopper;

    my $maq_pathname = Genome::Model::Tools::Maq->path_for_maq_version($self->version);
    my $consensus_dir = $self->consensus_directory;
    unless (-d $consensus_dir) {
        unless (Genome::Utility::FileSystem->create_directory($consensus_dir)) {
            $self->error_message("Failed to create consensus directory $consensus_dir:  $!");
            return;
        }
    }

    my $consensus_file = $self->consensus_output;
    my $ref_seq_file = $self->reference_sequence_input;
    my $accumulated_alignments_file = $self->aligned_reads_input;

    my $cmd = $maq_pathname .' assemble '. $genotyper_params.' '. $consensus_file .' '. $ref_seq_file .' '. $accumulated_alignments_file;
    $self->status_message("\n************* UpdateGenotype cmd: $cmd *************************\n\n");
    Genome::Utility::FileSystem->shellcmd(
                    cmd => $cmd,
                    input_files => [$ref_seq_file,$accumulated_alignments_file],
                    output_files => [$consensus_file],
                );

    return $self->update_genotype_verify_successful_completion;
}

sub update_genotype_verify_successful_completion {
    my $self = shift;

    my $consensus_file = $self->consensus_output;
    unless (-e $consensus_file && -s $consensus_file > 20) {
        $self->error_message("Consensus file $consensus_file is too small");
        return;
    }
    return 1;
}

1;

