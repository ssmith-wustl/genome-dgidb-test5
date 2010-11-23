package Genome::Model::Tools::Annotate::FastTierPindel;

use strict;
use warnings;

use Genome;     
use File::Basename;

class Genome::Model::Tools::Annotate::FastTierPindel {
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

   my $input_file_temp = Genome::Utility::FileSystem->create_temp_file_path;
   $self->modify_insertions($self->variant_file, $input_file_temp, '-');

    ####pindel 0 size insertion hack####i
   my $tier1_temp = Genome::Utility::FileSystem->create_temp_file_path;
   my $tier2_temp = Genome::Utility::FileSystem->create_temp_file_path;
   my $tier3_temp = Genome::Utility::FileSystem->create_temp_file_path;
   my $tier4_temp = Genome::Utility::FileSystem->create_temp_file_path;




     my $tier1_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $input_file_temp . " -b " . $self->_tier1_bed . " > $tier1_temp";  

    my $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier1_cmd,
        input_files  => [ $input_file_temp ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

    my $tier2_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $input_file_temp . " -b " . $self->_tier2_bed . " > $tier2_temp";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier2_cmd,
        input_files  => [ $input_file_temp ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

    my $tier3_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $input_file_temp . " -b " . $self->_tier3_bed . " > $tier3_temp";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier3_cmd,
        input_files  => [ $input_file_temp ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );
    my $tier4_cmd = "/gsc/pkg/bio/bedtools/installed-64/intersectBed -wa -a " . $input_file_temp . " -b " . $self->_tier4_bed . " > $tier4_temp";  

    $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $tier4_cmd,
        input_files  => [ $input_file_temp ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );

     $self->modify_insertions($tier1_temp, $self->tier1_output, "+"); 
     $self->modify_insertions($tier2_temp, $self->tier2_output, "+");
     $self->modify_insertions($tier3_temp, $self->tier3_output, "+");
     $self->modify_insertions($tier4_temp, $self->tier4_output, "+");


}

sub modify_insertions {
    my $self=shift;
    my $input_file=shift;
    my $output_file=shift;
    my $mode = shift;
    my $ifh = IO::File->new($input_file);
    my $ofh = IO::File->new($output_file, ">");
    while(my $line = $ifh->getline) {
        my($chr,$start,$stop,$alleles)=split /\t/, $line;
        if($alleles =~ m/[ACGT]$/) { #insertion  ex: 0/C  letters come last
            if($mode eq '-') {
                $start--;
            }
            elsif($mode eq '+') {
                $start++;
            }
        }
        $ofh->print("$chr\t$start\t$stop\t$alleles");
    }
    $ifh->close;
    $ofh->close;
}

