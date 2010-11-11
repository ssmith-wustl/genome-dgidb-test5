package Genome::Model::Tools::Annotate::FastTier;

use strict;
use warnings;

use Genome;     
use File::Basename;

class Genome::Model::Tools::Annotate::FastTier {
    is => 'Command',
    has => [
    variant_file => {
        type => 'Text',
        is_input => 1,
    },
    ],
    has_optional => [
    tier1_output => {
        calculate_from => ['variant_file'],
        calculate => q{ "$variant_file.tier1"; },
        is_output => 1,
    },
    tier2_output => {
        calculate_from => ['variant_file'],
        calculate => q{ "$variant_file.tier2"; },
        is_output => 1,
    },
    tier3_output => {
        calculate_from => ['variant_file'],
        calculate => q{ "$variant_file.tier3"; },
        is_output => 1,
    },
    tier4_output => {
        calculate_from => ['variant_file'],
        calculate => q{ "$variant_file.tier4"; },
        is_output => 1,
    },
    _tier1_bed => {
        type => 'Text',
        default => "/gscmnt/ams1102/info/info/tier_bed_files/tier1.bed",
    },
    _tier2_bed => {
        type => 'Text',
        default => "/gscmnt/ams1102/info/info/tier_bed_files/tier2.bed",
    },
    _tier3_bed => {
        type => 'Text',
        default => "/gscmnt/ams1102/info/info/tier_bed_files/tier3.bed",
    },
    _tier4_bed => {
        type => 'Text',
        default => "/gscmnt/ams1102/info/info/tier_bed_files/tier4.bed",
    }, 
    ]

};

sub sub_command_sort_position { 15 }

sub help_brief {
    "tools used for adapting various file formats into a format the annotation tool can accept"
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools annotate adaptor ...    
EOS
}

sub execute {
    my $self=shift;

    unless(-s $self->variant_file) {
        $self->error_message("The variant file you supplied: " . $self->variant_file . " appears to be 0 size. You need computer more better.");
        return;
    }
    my ($variant_filename, $directory, undef) = fileparse($self->variant_file); 

    my $tier1_output = $self->tier1_output;
    my $tier2_output = $self->tier2_output;
    my $tier3_output = $self->tier3_output;
    my $tier4_output = $self->tier4_output;

    my $tier1_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $self->variant_file . " -b " . $self->_tier1_bed . " > $tier1_output";  

    my $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier1_cmd,
        input_files  => [ $self->variant_file ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

    my $tier2_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $self->variant_file . " -b " . $self->_tier2_bed . " > $tier2_output";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier2_cmd,
        input_files  => [ $self->variant_file ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

    my $tier3_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $self->variant_file . " -b " . $self->_tier3_bed . " > $tier3_output";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier3_cmd,
        input_files  => [ $self->variant_file ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );
    my $tier4_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $self->variant_file . " -b " . $self->_tier4_bed . " > $tier4_output";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier4_cmd,
        input_files  => [ $self->variant_file ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

}
