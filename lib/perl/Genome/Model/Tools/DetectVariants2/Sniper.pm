package Genome::Model::Tools::DetectVariants2::Sniper;

use warnings;
use strict;

use Genome;
use Workflow;

my $DEFAULT_VERSION = '0.7.3';
my $SNIPER_COMMAND = 'bam-somaticsniper';

class Genome::Model::Tools::DetectVariants2::Sniper {
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    doc => "Produces a list of high confidence somatic snps and indels.",
# TODO ... make sure this works without old default snv and indel params default => '-q 1 -Q 15',
    # Make workflow choose 64 bit blades
    has_param => [
        lsf_queue => {
            default_value => 'long'
        }, 
        lsf_resource => {
            default_value => 'rusage[mem=4000] select[type==LINUX64 && maxtmp>100000] span[hosts=1]',
        },
    ],
    # These are params from the superclass' standard API that we do not require for this class (dont show in the help)
    has_constant_optional => [
        sv_params=>{},
        capture_set_input=>{},
    ],
};

my %SNIPER_VERSIONS = (
    '0.7' => '/gsc/pkg/bio/samtools/sniper/somatic_sniper-v0.7/' . $SNIPER_COMMAND,
    '0.7.1' => '/gsc/pkg/bio/samtools/sniper/somatic_sniper-v0.7.1/' . $SNIPER_COMMAND,
    '0.7.2' => '/gsc/pkg/bio/samtools/sniper/somatic_sniper-v0.7.2/' . $SNIPER_COMMAND,
    '0.7.3' => '/gsc/pkg/bio/samtools/sniper/somatic_sniper-v0.7.3/' . $SNIPER_COMMAND,
);

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt somatic sniper --aligned-reads-input tumor.bam --control-aligned-reads-input normal.bam --output-directory sniper
gmt somatic sniper --aligned-reads tumor.bam --control normal.bam --out sniper --quality 25
EOS
}

sub help_detail {                           
    return <<EOS 
    Provide a tumor and normal BAM file and get a list of somatic snps.  
EOS
}

sub _detect_variants {
    my $self = shift;
    $DB::single = 1;

    $self->status_message("beginning execute");

    # Run sniper C program... run twice if we get different sets of params for snps and indels
    my $snv_params = $self->snv_params || "";
    my $indel_params = $self->indel_params || "";
    my $result;
    if ( ($self->detect_snvs && $self->detect_indels) && ($snv_params eq $indel_params) ) {
        $result = $self->_run_sniper($snv_params, $self->_snv_staging_output, $self->_indel_staging_output);
    } else {
        # Run twice, since we have different parameters. Detect snps and throw away indels, then detect indels and throw away snps
        if ($self->detect_snvs && $self->detect_indels) {
            $self->status_message("Snp and indel params are different. Executing sniper twice: once each for snps and indels with their respective parameters");
        }
        my ($temp_fh, $temp_name) = Genome::Sys->create_temp_file();

        if ($self->detect_snvs) {
            $result = $self->_run_sniper($snv_params, $self->_snv_staging_output, $temp_name);
        }
        if ($self->detect_indels) {
            if($self->detect_snps and not $result) {
                $self->status_message('Sniper did not report success for snp detection. Skipping indel detection.')
            } else {
                $result = $self->_run_sniper($indel_params, $temp_name, $self->_indel_staging_output);
            }
        }
    }
    
    #Manually check for $self->_indel_staging_output as there might not be any indels and shellcmd()
    # chokes unless either all are present or all are empty.
    #(This means shellcmd() can check for the SNPs file on its own and still work given an empty result.)
    #Varied the warning text slightly so this message can be disambiguated from shellcmd() output in future debugging
    unless(-s $self->_indel_staging_output) {
        #Touch the file to make sure it exists
        my $fh = Genome::Sys->open_file_for_writing($self->_indel_staging_output);
        unless ($fh) {
            $self->error_message("failed to touch " . $self->_indel_staging_output . "!: " . Genome::Sys->error_message);
            die;
        }
        $fh->close;
        
        $self->warning_message("ALLOWING zero size output file " . $self->_indel_staging_output);
    }

    $self->status_message("ending execute");
    return $result; 
}

sub _run_sniper {
    my ($self, $params, $snp_output, $indel_output) = @_;
    
    my $cmd = $self->sniper_path . " " . $params . " -f ".$self->reference_sequence_input." ".$self->aligned_reads_input." ".$self->control_aligned_reads_input ." " . $snp_output . " " . $indel_output; 
    my $result = Genome::Sys->shellcmd( cmd=>$cmd, input_files=>[$self->aligned_reads_input,$self->control_aligned_reads_input], output_files=>[$snp_output], skip_if_output_is_present=>0, allow_zero_size_output_files => 1, );

    return $result;
}

sub sniper_path {
    my $self = $_[0];
    return $self->path_for_sniper_version($self->version);
}

sub available_sniper_versions {
    my $self = shift;
    return keys %SNIPER_VERSIONS;
}

sub path_for_sniper_version {
    my $class = shift;
    my $version = shift;

    if (defined $SNIPER_VERSIONS{$version}) {
        return $SNIPER_VERSIONS{$version};
    }
    die('No path for bam-somaticsniper version '. $version);
}

sub default_sniper_version {
    die "default bam-somaticsniper version: $DEFAULT_VERSION is not valid" unless $SNIPER_VERSIONS{$DEFAULT_VERSION};
    return $DEFAULT_VERSION;
}

sub has_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        $version = $self->version;
    }
    if(exists($SNIPER_VERSIONS{$version})){
        return 1;
    }
    return 0;
}

1;
