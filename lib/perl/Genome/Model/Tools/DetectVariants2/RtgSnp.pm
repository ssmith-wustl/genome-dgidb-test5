package Genome::Model::Tools::DetectVariants2::RtgSnp;

use strict;
use warnings;

use Genome;
use IO::File;
use File::Basename;

class Genome::Model::Tools::DetectVariants2::RtgSnp {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has_param => [
        lsf_resource => {
            default => "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>1000 && mem>16000] span[hosts=1] rusage[tmp=1000:mem=16000]' -M 1610612736",
        }
    ],
    has => [
    ]
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 rtg-snp
EOS
}

sub help_detail {
    return <<EOS 
This tool runs rtg for detection of SNVs.
EOS
}

sub _detect_variants {
    my $self = shift;
    
    my $ref_seq_file = $self->reference_sequence_input;
    my $bam_file = $self->aligned_reads_input;
    my $parameters = $self->params;

    my $rtg_cmd = "/gscmnt/gc2146/info/medseq/rtg_software/rtg-BETA-2011-04-29-34609/rtg snp";
    
    #add path to reference
    $rtg_cmd .= " -t /gscmnt/gc2146/info/medseq/rtg_software/rtg-BETA-2011-04-29-34609/101947881_build36";

    #add path to output
    $rtg_cmd .= " -o ".$self->_temp_staging_directory."/rtg";

    #add SNPS only option
    $rtg_cmd .= " --snps-only";

    #set correct error model
    $rtg_cmd .= " --machine-errors=illumina";

    #don't gzip output
    $rtg_cmd .= " -Z";

    #bam input file
    $rtg_cmd .= " $bam_file";

    Genome::Sys->shellcmd( cmd => $rtg_cmd);

    Genome::Sys->copy_file($self->_temp_staging_directory."/rtg/snps.txt", $self->_temp_staging_directory."/rtg/snvs.hq"); 
    my @files = glob($self->_temp_staging_directory."/rtg/*");
    for my $file (@files) {
        if(-d $file){
            next;
        }
        my $basename = basename($file);
        Genome::Sys->copy_file($file, $self->_temp_staging_directory."/".$basename);
    }

    return 1;
}
sub has_version {
    my $self = shift;
    my $version = shift;
    return 1;
}


=cut
# Override the base method so we can skip using control_aligned_reads...  this was we can shortcut between somatic-variation and ref-align runs 
sub params_for_result {
    my $self = shift;

    my %params = (
        detector_name => $self->class,
        detector_params => $self->params,
        detector_version => $self->version,
        aligned_reads => $self->aligned_reads_input,
        control_aligned_reads => undef,
        reference_build_id => $self->reference_build_id,
        region_of_interest_id => $self->region_of_interest_id,
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
        chromosome_list => undef,
    );

    return \%params;
}
=cut

1;
