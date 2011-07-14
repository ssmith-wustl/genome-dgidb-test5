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

    unless ($self->version) {
        die $self->error_message("A version of VarscanSomatic must be specified");
    }

    my $varscan = Genome::Model::Tools::Varscan::Somatic->create(
        normal_bam => $self->control_aligned_reads_input,
        tumor_bam => $self->aligned_reads_input,,
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

    my ($chromosome, $position, $reference, undef,$depth1, $depth2, undef, undef, undef,$qual , undef,$consensus, @extra) = split("\t", $line);

    if ($consensus =~ /-|\+/) {
        return $class->_parse_indel_for_bed_intersection($line);
    } else {
        return $class->_parse_snv_for_bed_intersection($line);
    }
}

sub _parse_indel_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    my ($chromosome, $position, $_reference, undef,$depth1, $depth2, undef, undef, undef,$qual , undef,$consensus, @extra) = split("\t", $line);
    
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

    my ($chromosome, $position, $reference, undef,$depth1, $depth2, undef, undef, undef,$qual , undef,$consensus, @extra) = split("\t", $line);

    return [$chromosome, $position, $reference, $consensus];
}



1;

