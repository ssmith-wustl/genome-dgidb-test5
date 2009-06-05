package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Samtools;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Samtools {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
       ],
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


sub help_brief {
    "Use samtools to find snps and idels"
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment find-variations samtools --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the reference-alignment solexa pipeline process
EOS
}


sub execute {
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;

    #my $sam_pathname = $self->proper_sam_pathname('read_aligner_version');
    #my $sam_pathname = '/gscuser/dlarson/samtools/r301wu1/samtools';
    my $sam_pathname = Genome::Model::Tools::Sam->path_for_samtools_version($model->indel_finder_version);

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_sequence_path.'/all_sequences.fasta';
    my $rv = $self->check_for_existence($ref_seq_file);
    return unless $self->_check_rv("reference sequence file $ref_seq_file does not exist", $rv);
    
    my $analysis_base_path = $self->analysis_base_path;
    unless (-d $analysis_base_path) {
        $rv = $self->create_directory($analysis_base_path);
        return unless $self->check_rv("Failed to create directory: $analysis_base_path", $rv);
        chmod 02775, $analysis_base_path;
    }

    #my ($pileup_file) =  $build->_consensus_files($self->ref_seq_id).'.samtools_pileup';
    my $maplist_dir = $build->accumulated_alignments_directory;
    #my ($bam_file)  = glob("$maplist_dir/".$model->subject_name."*_rmdup.bam");
    my ($bam_file)  = $build->whole_rmdup_bam_file; 

    $rv = $self->check_for_existence($bam_file);
    return unless $self->_check_rv("Bam output file $bam_file was not found.", $rv);
    
    my $snp_output_file          = $self->snp_output_file;
    my $filtered_snp_output_file = $self->filtered_snp_output_file;
    my $indel_output_file        = $self->indel_output_file;
    my $filtered_indel_file      = $self->indel_output_file . '.filtered';

    # Remove the result files from any previous run
    unlink($snp_output_file, $filtered_snp_output_file, $indel_output_file, $filtered_indel_file);

    my $samtools_cmd = "$sam_pathname pileup -c -f $ref_seq_file";

    $rv = system "$samtools_cmd -S $bam_file > $snp_output_file";
    return unless $self->_check_rv("Running samtools SNP failed with exit code $rv", $rv, 0);

    $rv = system "$samtools_cmd -i $bam_file > $indel_output_file";
    return unless $self->_check_rv("Running samtools indel failed with exit code $rv", $rv, 0);

    $rv = system "gt sam indel-filter --indel-file $indel_output_file";
    return unless $self->_check_rv("Running gt sam indel-filter failed with ext code $rv", $rv, 0);
   
    $rv = system "gt sam snp-filter --snp-file $snp_output_file --out-file $filtered_snp_output_file --indel-file $filtered_indel_file";
    return unless $self->_check_rv("Running gt sam snp-filter failed with exit code $rv", $rv, 0);
    
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
        my $rv = -e $file && -s $file;
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

