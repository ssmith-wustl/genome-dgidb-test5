package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Maq;

#REVIEW fdu
#short:
#1. Fix help_synopsis
#2. replace lookup_iub_code with calling class method in Genome::Info::IUB
#3. replace generate_genotype_detail_file subroutine with G::M::T::Snp::GenotypeDetail
#4. Change to get ref_seq_file via reference_build->full_consensus_path('bfa')
#5. No need to list analysis_base_path, snp_output_file ... as properties
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

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::Maq {
    is  => ['Genome::Model::Command::Build::ReferenceAlignment::FindVariations'],
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
            calculate_from => ['analysis_base_path','ref_seq_id'],
            calculate      => q|
                return $analysis_base_path .'/snps_'. $ref_seq_id;
            |,
        },
        indel_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path','ref_seq_id'],
            calculate      => q|
                return $analysis_base_path .'/indels_'. $ref_seq_id;
            |,
        },
        pileup_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path','ref_seq_id'],
            calculate      => q|
                return $analysis_base_path .'/pileup_'. $ref_seq_id;
            |,
        },
        filtered_snp_output_file => {
            doc => "",
            calculate_from => ['analysis_base_path'],
            calculate      => q|
                return $analysis_base_path .'/filtered.indelpe.snps';
            |,
        },
        genotype_detail_file => {
            doc => "",
            calculate_from => ['analysis_base_path','ref_seq_id'],
            calculate      => q|
                return $analysis_base_path .'/report_input_'. $ref_seq_id;
            |,
        },
    ],
};

sub help_brief {
    "Use maq tool to find snps and idels"
}

sub help_synopsis {
    return <<"EOS"
    genome model build reference-alignment find-variations maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the solexa reference-alignment pipeline process
EOS
}


sub execute {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;

    my $maq_pathname    = Genome::Model::Tools::Maq->path_for_maq_version($model->indel_finder_version);
    my $maq_pl_pathname = Genome::Model::Tools::Maq->proper_maq_pl_pathname($model->indel_finder_version);

    # ensure the reference sequence exists.
    my $ref_seq_file = $model->reference_build->full_consensus_path('bfa');
    my $rv = $self->check_for_existence($ref_seq_file);
    return unless $self->_check_rv("reference sequence file $ref_seq_file does not exist", $rv);

    my $analysis_base_path = $self->analysis_base_path;
    unless (-d $analysis_base_path) {
        $rv = $self->create_directory($analysis_base_path);
        return unless $self->_check_rv("Failed to create directory: $analysis_base_path", $rv);
        chmod 02775, $analysis_base_path;
    }

    my ($assembly_output_file) =  $build->_consensus_files($self->ref_seq_id);
    $rv = $self->check_for_existence($assembly_output_file);
    return unless $self->_check_rv("Assembly output file $assembly_output_file does not exist", $rv);

    my $snp_output_file    =  $self->snp_output_file;
    my $indel_output_file  =  $self->indel_output_file;
    my $pileup_output_file = $self->pileup_output_file;
    my $filtered_snp_output_file = $self->filtered_snp_output_file;

    my $accumulated_alignments = $build->whole_rmdup_map_file;
    my $indelpe_file           = $analysis_base_path . '/indelpe.out';
    my $sorted_indelpe_file    = $analysis_base_path . '/indelpe.sorted.out';
    
    # Remove the result files from any previous run
    unlink ($snp_output_file, $filtered_snp_output_file, $indel_output_file, $pileup_output_file, $indelpe_file, $sorted_indelpe_file);

    my $cmd = "$maq_pathname cns2snp $assembly_output_file > $snp_output_file";
    $rv = system $cmd;
    return unless $self->_check_rv("cns2snp.\ncmd: $cmd", $rv, 0);

    $cmd = "$maq_pathname indelsoa $ref_seq_file $accumulated_alignments > $indel_output_file";
    $rv = system $cmd;
    return unless $self->_check_rv("indelsoa.\ncmd: $cmd", $rv, 0);

    my $filter = 'perl -nae '."'".'print if $F[2] =~ /^(\*|\+)$/'."'";
    $cmd = "$maq_pathname indelpe $ref_seq_file $accumulated_alignments | $filter > $indelpe_file";
    $rv = system $cmd;
    return unless $self->_check_rv("indelpe.\ncmd: $cmd", $rv, 0);

    $rv = Genome::Model::Tools::Snp::Sort->execute(
        snp_file    => $indelpe_file,
        output_file => $sorted_indelpe_file,
    );
    return unless $self->_check_rv('Failed to run gmt snp sort', $rv);
        
    my $indel_param;
    if (-s $sorted_indelpe_file) {
        $indel_param = "-F '$sorted_indelpe_file'";
    }
    else {
        $self->warning_message('Omitting indelpe data from the SNPfilter results because no indels were found');
        $indel_param = '';
    }

    $cmd = "$maq_pl_pathname SNPfilter $indel_param $snp_output_file > $filtered_snp_output_file";
    $rv = system $cmd;
    return unless $self->_check_rv("SNPfilter.\ncmd: $cmd", $rv, 0);
    
    # Running pileup requires some parsing of the snp file
    my $tmpfh = File::Temp->new();
    my $snp_fh = IO::File->new($snp_output_file);
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
        $ref_seq_file,
        $accumulated_alignments,
        $pileup_output_file
    );

    $rv = system $cmd;
    return unless $self->_check_rv("pileup.\ncmd: $cmd", $rv, 0);

    $rv = $self->generate_genotype_detail_file;
    return unless $self->_check_rv('Generating genotype detail file errored out', $rv);

    $rv = $self->generate_metrics;
    return unless $self->_check_rv('Error generating metrics.', $rv);

    return $self->verify_successful_completion;
}


sub generate_metrics {
    my $self = shift;

    map{$_->delete}($self->metrics);

    my $snp_count      = 0;
    my $snp_count_good = 0;
    my $indel_count    = 0;

    my $snp_fh = IO::File->new($self->snp_output_file);
    while (my $row = $snp_fh->getline) {
        $snp_count++;
        my ($r,$p,$a1,$a2,$q,$c) = split /\s+/, $row;
        $snp_count_good++ if $q >= 15 and $c > 2;
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

    for my $file ($self->snp_output_file, $self->pileup_output_file, $self->filtered_snp_output_file, $self->indel_output_file) {
        my $rv = -e $file;
        return unless $self->_check_rv("File $file doesn't exist or has no data", $rv);
    }

    return 1;
}


sub generate_genotype_detail_file {
    my $self  = shift;
    my $model = $self->model; 

    my $snp_output_file    = $self->snp_output_file;
    my $pileup_output_file = $self->pileup_output_file;
    my $report_input_file  = $self->genotype_detail_file;

    for my $file ($snp_output_file, $pileup_output_file) {
        my $rv = -f $file and -s $file;
        return unless $self->_check_rv("File $file dosen't exist or has no data", $rv);
    }

    unlink $report_input_file if -e $report_input_file;
    my $report_fh = IO::File->new(">$report_input_file");
    
    my $snp_gd = Genome::Model::Tools::Snp::GenotypeDetail->create(
        snp_file   => $snp_output_file,
        out_file   => $report_input_file,
        snp_format => 'maq',
        maq_pileup_file => $pileup_output_file,
    );

    return $snp_gd->execute;
}

 
sub _check_rv {
    my ($self, $msg, $rv, $cmp) = @_;

    if (defined $cmp) {
        $msg = 'Failed to run maq '.$msg;
        return 1 if $rv == $cmp;
    }
    else {
        return $rv if $rv;
    }

    $self->error_message($msg);
    return;
}

1;

