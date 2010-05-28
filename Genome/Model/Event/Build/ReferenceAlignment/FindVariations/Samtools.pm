package Genome::Model::Event::Build::ReferenceAlignment::FindVariations::Samtools;

#REVIEW fdu
#No need to list analysis_base_path, snp_output_file ... as properties
#and do calculation there. They should be moved to the body of execute and 
#resolved their values there.

use strict;
use warnings;

use Genome;
use IO::File;
use File::Copy qw(move);

class Genome::Model::Event::Build::ReferenceAlignment::FindVariations::Samtools {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::FindVariations'],
    has => [
        analysis_base_path => {
            doc => "the path at which all analysis output is stored",
            calculate_from => ['build'],
            calculate      => q|
                return $build->snp_related_metric_directory;
            |,
            is_constant => 1,
        },
        snp_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path', 'ref_seq_id'],
            calculate      => q|
                return $analysis_base_path.'/snps_'.$ref_seq_id;
            |,
        },
        filtered_snp_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path'],
            calculate      => q|
                return $analysis_base_path.'/filtered.indelpe.snps';
            |,
        },
        indel_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path', 'ref_seq_id'],
            calculate      => q|
                return $analysis_base_path.'/indels_'.$ref_seq_id;
            |,
        },
        genotype_detail_file => {
            doc => "",
            calculate_from => ['analysis_base_path', 'ref_seq_id'],
            calculate      => q|
                return $analysis_base_path.'/report_input_'.$ref_seq_id;
            |,
        },
    ],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=12000]' -M 1610612736";
}


sub execute {
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;

    my $sam_pathname = Genome::Model::Tools::Sam->path_for_samtools_version($model->indel_finder_version);

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_build->full_consensus_path('fa');
    my $rv = $self->check_for_existence($ref_seq_file);
    return unless $self->_check_rv("reference sequence file $ref_seq_file does not exist", $rv);
    
    my $analysis_base_path = $self->analysis_base_path;
    unless (-d $analysis_base_path) {
        $rv = $self->create_directory($analysis_base_path);
        return unless $self->_check_rv("Failed to create directory: $analysis_base_path", $rv);
        chmod 02775, $analysis_base_path;
    }

    my $maplist_dir = $build->accumulated_alignments_directory;
    my ($bam_file)  = $build->whole_rmdup_bam_file; 

    $rv = $self->check_for_existence($bam_file);
    return unless $self->_check_rv("Bam output file $bam_file was not found.", $rv);
    
    my $snp_output_file          = $self->snp_output_file;
    my $filtered_snp_output_file = $self->filtered_snp_output_file;
    my $indel_output_file        = $self->indel_output_file;
    my $filtered_indel_file      = $self->indel_output_file . '.filtered';

    # Remove the result files from any previous run
    unlink($snp_output_file, $filtered_snp_output_file, $indel_output_file, $filtered_indel_file);
 
    my $indel_finder_params = (defined $model->indel_finder_params ? $model->indel_finder_params : '');

    my $samtools_cmd = "$sam_pathname pileup -c $indel_finder_params -f $ref_seq_file";

    #Originally "-S" was used as SNP calling. In r320wu1 version, "-v" is used to replace "-S" but with 
    #double indel lines embedded, this need sanitized
    #$rv = system "$samtools_cmd -S $bam_file > $snp_output_file"; 
    
    my $snp_cmd = "$samtools_cmd -v $bam_file > $snp_output_file";
    $rv = system $snp_cmd;  
    return unless $self->_check_rv("Running samtools SNP failed with exit code $rv\nCommand: $snp_cmd", $rv, 0);

    my $snp_sanitizer = Genome::Model::Tools::Sam::SnpSanitizer->create(snp_file => $snp_output_file);
    $rv = $snp_sanitizer->execute;
    return unless $self->_check_rv("Running samtools snp-sanitizer failed with exit code $rv", $rv, 1);

    my $indel_cmd = "$samtools_cmd -i $bam_file > $indel_output_file";
    $rv = system $indel_cmd;
    return unless $self->_check_rv("Running samtools indel failed with exit code $rv\nCommand: $indel_cmd", $rv, 0);

    #for capture models we need to limit the snps and indels to within the defined target regions
    if ($self->model->region_of_interest_set_name) {
        my $bed_file = $self->build->region_of_interest_set_bed_file;
        for my $var_file ($snp_output_file, $indel_output_file) {
            my $tmp_limited_file = $var_file .'_limited';
            my $no_limit_file = $var_file .'.no_bed_limit';
            unless (Genome::Model::Tools::Sam::LimitVariants->execute(
                variants_file => $var_file,
                bed_file => $bed_file,
                output_file => $tmp_limited_file,
            )) {
                $self->error_message('Failed to limit samtools variants '. $var_file .' to within regions of interest '. $bed_file);
                die($self->error_message);
            }
            unless (move($var_file,$no_limit_file)) {
                $self->error_message('Failed to move all variants from '. $var_file .' to '. $no_limit_file);
                die($self->error_message);
            }
            unless (move($tmp_limited_file,$var_file)) {
                $self->error_message('Failed to move limited variants from '. $tmp_limited_file .' to '. $var_file);
                die($self->error_message);
            }
        }
    }
    
    #For test purpose, put filter switch here. In the future, probably only one is needed.
    my $filter_type = $model->variant_filter || 'SnpFilter';

    if ($filter_type =~ /^VarFilter$/i) {
        my %params = (
            bam_file     => $bam_file,
            ref_seq_file => $ref_seq_file,
            filtered_snp_out_file   => $filtered_snp_output_file,
            filtered_indel_out_file => $filtered_indel_file,
        );
        
        my $varfilter = Genome::Model::Tools::Sam::VarFilter->create(%params);
        $rv = $varfilter->execute;
        return unless $self->_check_rv("Running samtools varFilter failed with exit code $rv", $rv, 1);
    }
    elsif ($filter_type =~ /^SnpFilter$/i) {
        my %indel_filter_params = ( indel_file => $indel_output_file);
        # for capture data we do not know the proper ceiling for depth
        if ($self->model->region_of_interest_set_name) {
            # SHOULD THIS BE A PART OF THE PROCESSING PROFILE THOUGH???
            $indel_filter_params{max_read_depth} = 1000000;
        }
        my $indel_filter = Genome::Model::Tools::Sam::IndelFilter->create(%indel_filter_params);
        $rv = $indel_filter->execute;
        return unless $self->_check_rv("Running sam indel-filter failed with exit code $rv", $rv, 1);
   
        my $snp_filter = Genome::Model::Tools::Sam::SnpFilter->create(
            snp_file   => $snp_output_file,
            out_file   => $filtered_snp_output_file,
            indel_file => $filtered_indel_file,
        );
        $rv = $snp_filter->execute;
        return unless $self->_check_rv("Running sam snp-filter failed with exit code $rv", $rv, 1);
    }
    else {
        $self->error_message("Invalid variant filter type: $filter_type");
        return;
    }
    
    $rv = $self->generate_genotype_detail_file;
    return unless $self->_check_rv('Generating genotype detail file errored out', $rv);
    
    $rv = $self->generate_metrics;
    return unless $self->_check_rv('Error generating metrics.', $rv);
    
    return $self->verify_successful_completion;
}


sub generate_metrics {
    my $self = shift;
    
    my $snp_count      = 0;
    my $snp_count_good = 0;
    my $indel_count    = 0;

    map{$_->delete}($self->metrics);

    my $snp_fh = IO::File->new($self->snp_output_file);
    while (my $row = $snp_fh->getline) {
        $snp_count++;
        my @columns = split /\s+/, $row;
        $snp_count_good++ if $columns[4] >= 15 and $columns[7] > 2;
    }

    my $indel_fh = IO::File->new($self->indel_output_file);
    while (my $row = $indel_fh->getline) {
        $indel_count++;
    }

    $self->add_metric(name => 'total_snp_count', value => $snp_count);
    $self->add_metric(name => 'confident_snp_count', value => $snp_count_good);
    $self->add_metric(name => 'total indel count', value => $indel_count);
    
    print $self->{ref_seq_id}."\t$snp_count\t$snp_count_good\t$indel_count\n";
    return 1;
}


sub verify_successful_completion {
    my $self = shift;

    for my $file ($self->snp_output_file, $self->filtered_snp_output_file, $self->indel_output_file) {
        #my $rv = -e $file && -s $file;  For the sake of testing purpose
        my $rv = -e $file;
        return unless $self->_check_rv("File $file is not valid", $rv);
    }
    
    return 1;
}


sub generate_genotype_detail_file {
    my $self = shift; 

    my $snp_output_file = $self->snp_output_file;
    my $rv = -f $snp_output_file and -s $snp_output_file;
    return unless $self->_check_rv("SNP output File: $snp_output_file is invalid.", $rv); 
        
    my $report_input_file = $self->genotype_detail_file;
    unlink $report_input_file if -e $report_input_file;

    my $snp_gd = Genome::Model::Tools::Snp::GenotypeDetail->create(
        snp_file   => $snp_output_file,
        out_file   => $report_input_file,
        snp_format => 'sam',
    );
    
    return $snp_gd->execute;
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
    return;
}
    

1;

