package Genome::Model::Tools::DetectVariants2::Varscan;

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::DetectVariants2::Varscan {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has => [
        params => {
            default => '--min-var-freq 0.10 --p-value 0.10 --somatic-p-value 0.01',
        },
    ],
    has_param => [
        lsf_resource => {
            default => "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=16000]' -M 1610612736",
        }
    ],
};

sub help_brief {
    "Use Varscan for variant detection.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 varscan --aligned_reads_input input.bam --reference_sequence_input reference.fa --output-directory ~/example/
EOS
}

sub help_detail {
    return <<EOS 
This tool runs Varscan for detection of SNPs and/or indels.
EOS
}

sub _detect_variants {
    my $self = shift;

    ## Get required parameters ##
    my $output_snp = $self->_temp_staging_directory."/snvs.hq";
    my $output_indel = $self->_temp_staging_directory."/indels.hq";

    unless ($self->version) {
        die $self->error_message("A version of Varscan must be specified");
    }

    my $varscan = Genome::Model::Tools::Varscan::Germline->create(
        bam_file => $self->aligned_reads_input,
        reference => $self->reference_sequence_input,
        output_snp => $output_snp,
        output_indel => $output_indel,
        varscan_params => $self->params,
        no_headers => 1,
        version => $self->version,
    );

    unless($varscan->execute()) {
        $self->error_message('Failed to execute Varscan: ' . $varscan->error_message);
        return;
    }

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
    my @versions = Genome::Model::Tools::Varscan->available_varscan_versions;
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

    if ($consensus =~ /\*/) {
        return $class->_parse_indel_for_bed_intersection($line);
    } else {
        return $class->_parse_snv_for_bed_intersection($line);
    }
}

sub _parse_indel_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $_reference, $consensus, @extra) = split "\t",  $line;
    
    #TODO clean all of this up. It is based on logic from Genome::Model::Tools::Bed::Convert::Indel::VarscanToBed in process_source... 
    # this should be smarter about using that work ... perhaps process_source should call a method that just parses one line, and this method can be replaced by a call to that instead
    my ($indel_call_1, $indel_call_2) = split('/', $consensus);
    if(defined($indel_call_2)){
        if($indel_call_1 eq $indel_call_2) {
            undef $indel_call_2;
        }
    }
    my ($reference, $variant, $start, $stop);
    for my $indel ($indel_call_1, $indel_call_2) {
        next unless defined $indel;
        next if $indel eq '*'; #Indicates only one indel call...and this isn't it!

        $start = $position - 1; #Convert to 0-based coordinate

        if(substr($indel,0,1) eq '+') {
            $reference = '*';
            $variant = substr($indel,1);
            $stop = $start; #Two positions are included-- but an insertion has no "length" so stop and start are the same
        } elsif(substr($indel,0,1) eq '-') {
            $start += 1; #varscan reports the position before the first deleted base
            $reference = substr($indel,1);
            $variant = '*';
            $stop = $start + length($reference);
        } else {
            $class->warning_message("Unexpected indel format encountered ($indel) on line:\n$line");
            return;
        }
    }

    unless (defined $chromosome && defined $position && defined $reference && defined $variant) {
        die $class->error_message("Could not get chromosome, position, reference, or variant for line: $line");
    }

    return [$chromosome, $stop, $reference, $variant];

}

sub _parse_snv_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $reference, $consensus, @extra) = split("\t", $line);

    return [$chromosome, $position, $reference, $consensus];
}

1;
