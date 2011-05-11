package Genome::Model::Tools::FastTier::FastTier;

use strict;
use warnings;

use Genome;     
use File::Basename;
use File::Copy;

class Genome::Model::Tools::FastTier::FastTier {
    is => 'Command',
    has => [
        variant_bed_file => {
            type => 'Text',
            is_input => 1,
        },
    ],
    has_optional => [
        indels => {
            type => 'Boolean',
            is_input => 1,
            default => 0,
            doc => "Set this to true if you have any items in the bed file which have start_pos == stop_pos. It creates a temp file and dumps your input
                    into it in order to get around bedtools silently failing when start==stop",
        },
        tier1_output => {
            is => 'Text',
            is_optional => 1,
            is_input => 1, 
            is_output => 1,
        },
        tier2_output => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            is_output => 1,
        },
        tier3_output => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            is_output => 1,
        },
        tier4_output => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            is_output => 1,
        },
        tier_file_location => {
            type => 'Text',
            is_input => 1,
            default => '/gscmnt/ams1100/info/model_data/2771411739/build102550711/annotation_data/tiering_bed_files_v2',
            doc => 'Use this to point to a directory containing tier1.bed - tier4.bed in order to use different bed files for tiering',
        },
        intersect_bed_bin_location => {
            type => 'Text',
            is_input => 1,
            default => '/gscmnt/sata921/info/medseq/intersectBed/intersectBed-pipes',  #'/gsc/pkg/bio/bedtools/installed-64/intersectBed',
            doc => 'The path and filename of intersectBed',
        },
        _tier1_bed => {
            type => 'Text',
        },
        _tier2_bed => {
            type => 'Text',
        },
        _tier3_bed => {
            type => 'Text',
        },
        _tier4_bed => {
            type => 'Text',
        }, 
    ]

};

sub sub_command_sort_position { 15 }

sub help_brief {
    "This tool uses the GC customized version of intersectBed in order to stream a bedfile end to end, dropping the appropriate items in the appropriate tier files."
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt fast-tier fast-tier-pipes
EOS
}

sub execute {
    my $self=shift;
    unless(-s $self->variant_bed_file) {
        $self->error_message("The variant file you supplied: " . $self->variant_bed_file . " appears to be 0 size. You need computer more better.");
        return;
    }

    for my $tier(1..4){
        my $output_accessor = "tier".$tier."_output";
        unless ($self->$output_accessor){
            $self->$output_accessor($self->variant_bed_file.".tier".$tier);
        }
    }

    #if the user specified an alternate location for tier bed files, check and load them
    if(defined($self->tier_file_location)){
        unless(-d $self->tier_file_location){
            $self->error_message("You must specify a directory containing the 4 tier files.");
            die $self->error_message;
        }
        my @tiers = map { $self->tier_file_location."/tier".$_.".bed";} (1,2,3,4);
        for my $t (@tiers){
            unless(-s $t){
                $self->error_message("Could not locate a bed file at ".$t."\n");
                die $self->error_message;
            }
        }
        $self->_tier1_bed($tiers[0]);
        $self->_tier2_bed($tiers[1]);
        $self->_tier3_bed($tiers[2]);
        $self->_tier4_bed($tiers[3]);
    }
    $self->status_message("Using tier 1 bed file  at ".$self->_tier1_bed ."\n");
    $self->status_message("Using tier 2 bed file  at ".$self->_tier2_bed ."\n");
    $self->status_message("Using tier 3 bed file  at ".$self->_tier3_bed ."\n");
    $self->status_message("Using tier 4 bed file  at ".$self->_tier4_bed ."\n");
    
    my $tier1_cmd = $self->intersect_bed_bin_location." -wa -vf stdout -of ".$self->tier1_output." -u -a ".$self->variant_bed_file." -b ".$self->_tier1_bed;
    my $tier2_cmd = $self->intersect_bed_bin_location." -wa -vf stdout -of ".$self->tier2_output." -u -a stdin -b ".$self->_tier2_bed;
    my $tier3_cmd = $self->intersect_bed_bin_location." -wa -vf stdout -of ".$self->tier3_output." -u -a stdin -b ".$self->_tier3_bed;
    my $tier4_cmd = $self->tier4_output;

    my $cmd = $tier1_cmd . " | " . $tier2_cmd . " | " . $tier3_cmd . " > " . $tier4_cmd;

    my $result = Genome::Sys->shellcmd( cmd => $cmd );

    return 1;
}
