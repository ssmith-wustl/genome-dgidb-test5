package Genome::Model::Tools::DetectVariants2::Polymutt;

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::DetectVariants2::Polymutt {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    #has => [
    #    params => {},
    #],
    has_param => [
        lsf_resource => {
            default => "-R 'select[ncpus>=4] span[hosts=1] rusage[mem=16000]' -M 1610612736 -n 4",
        }
    ],
};

sub help_brief {
    "Use Polymutt for variant detection.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 polymutt --alignment-results input.bam --reference_sequence_input reference.fa --output-directory ~/example/
EOS
}

sub help_detail {
    return <<EOS 
This tool runs Polymutt for detection of SNPs and/or indels.
EOS
}

sub _supports_cross_sample_detection {
    my ($class, $version, $vtype, $params) = @_;
    return 1;
};

sub _detect_variants {
    my $self = shift;

    my $version = $self->version;
    unless ($version) {
        die $self->error_message("A version of Polymutt must be specified");
    }

    # once this is deployed as a Debian package, this is removed
    #my $polymutt_path = Genome::Sys->swpath("polymutt",$version);
    my $polymutt_path = '/gscuser/dlarson/src/polymutt.0.01/bin/polymutt';

    # once this is deployed as a Debian package, this is removed
    #my $samtools_hybrid_path = Genome::Sys->swpath("samtools-hybrid",$version);
    my $samtools_hybrid_path = '/gscuser/dlarson/src/samtools-0.1.7a-hybrid/samtools-hybrid';

    my $refseq_fasta_path = '/gscmnt/ams1102/info/model_data/2869585698/build106942997/all_sequences.fa';

    my @a = $self->alignment_results;
    die "TODO: plug in Harris' workflow here\nPOLYMUTT RUN ON @a\n";

    for my $a (@a) {
        my $output_glf_path = $self->_temp_staging_directory . '/' . $a->id . '.glf';
        my $bam_path = $a->merged_alignment_bam_path;
        my $cmd = "$samtools_hybrid_path view -uh $bam_path | $samtools_hybrid_path calmd -Aur - $refseq_fasta_path 2> /dev/null | $samtools_hybrid_path pileup - -g -f  $refseq_fasta_path > $output_glf_path";
        Genome::Sys->shellcmd(
            cmd => $cmd,
            input_files => [$bam_path, $refseq_fasta_path],
            ouput_files => [$output_glf_path],
        );
    }


    ## Get required parameters ##
    my $output_snp = $self->_temp_staging_directory."/snvs.hq";

    # Grab the map_quality param and pass it separately
    my $params = $self->params;

    return 1;
}

sub generate_metrics {
    my $self = shift;

    my $metrics = {};
    
    if($self->detect_snvs) {
        my $snp_count      = 0;
        
        my $snv_output = $self->_snv_staging_output;
        my $snv_fh = Genome::Sys->open_file_for_reading($snv_output);
        while (my $row = $snv_fh->getline) {
            $snp_count++;
        }
        $metrics->{'total_snp_count'} = $snp_count;
    }

    if($self->detect_indels) {
        my $indel_count    = 0;
        
        my $indel_output = $self->_indel_staging_output;
        my $indel_fh = Genome::Sys->open_file_for_reading($indel_output);
        while (my $row = $indel_fh->getline) {
            $indel_count++;
        }
        $metrics->{'total indel count'} = $indel_count;
    }

    return $metrics;
}

sub has_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        $version = $self->version;
    }
    my @versions = Genome::Model::Tools::Polymutt->available_varscan_versions;
    for my $v (@versions){
        if($v eq $version){
            return 1;
        }
    }
    return 0;  
}

sub parse_line_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    unless ($line) {
        die $class->error_message("No line provided to parse_line_for_bed_intersection");
    }

    my ($chromosome, $position, $_reference, $consensus) = split "\t",  $line;

    if ($consensus =~ /\-|\+/) {
        return $class->_parse_indel_for_bed_intersection($line);
    } else {
        return $class->_parse_snv_for_bed_intersection($line);
    }
}

sub _parse_indel_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $_reference, $consensus, @extra) = split "\t",  $line;
    
    my @variants;
    my @indels = Genome::Model::Tools::Bed::Convert::Indel::PolymuttToBed->convert_indel($line);

    for my $indel (@indels) {
        my ($reference, $variant, $start, $stop) = @$indel;
        if (defined $chromosome && defined $position && defined $reference && defined $variant) {
            push @variants, [$chromosome, $stop, $reference, $variant];
        }
    }

    unless(@variants){
        die $class->error_message("Could not get chromosome, position, reference, or variant for line: $line");
    }

    return @variants;
}

sub _parse_snv_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $reference, $consensus, @extra) = split("\t", $line);

    return [$chromosome, $position, $reference, $consensus];
}

1;
