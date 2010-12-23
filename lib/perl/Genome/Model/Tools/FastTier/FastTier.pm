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
        exclusive_tiering => {
            type => 'Boolean',
            is_input =>1,
            default => 1,
            doc => 'This option tiers events in the highest tier possible, then removes it from the list of inputs to the next tier. If tiers overlap, this prevents events from showing up twice',
        },
        tier1_output => {
            calculate_from => ['variant_bed_file'],
            calculate => q{ "$variant_bed_file.tier1"; },
            is_output => 1,
        },
        tier2_output => {
            calculate_from => ['variant_bed_file'],
            calculate => q{ "$variant_bed_file.tier2"; },
            is_output => 1,
        },
        tier3_output => {
            calculate_from => ['variant_bed_file'],
            calculate => q{ "$variant_bed_file.tier3"; },
            is_output => 1,
        },
        tier4_output => {
            calculate_from => ['variant_bed_file'],
            calculate => q{ "$variant_bed_file.tier4"; },
            is_output => 1,
        },
        tier_file_location => {
            type => 'Text',
            is_input => 1,
            doc => 'Use this to point to a directory containing tier1.bed - tier4.bed in order to use different bed files for tiering',
        },
        intersect_bed_bin_location => {
            type => 'Text',
            is_input => 1,
            default => '/gscmnt/sata921/info/medseq/intersectBed/intersectBed',  #'/gsc/pkg/bio/bedtools/installed-64/intersectBed',
            doc => 'The path and filename of intersectBed',
        },
        _tier1_bed => {
            type => 'Text',
            default => "/gscmnt/sata921/info/medseq/make_tier_bed_files/NCBI-human-build36/tier1.bed",
        },
        _tier2_bed => {
            type => 'Text',
            default => "/gscmnt/sata921/info/medseq/make_tier_bed_files/NCBI-human-build36/tier2.bed",
        },
        _tier3_bed => {
            type => 'Text',
            default => "/gscmnt/sata921/info/medseq/make_tier_bed_files/NCBI-human-build36/tier3.bed",
        },
        _tier4_bed => {
            type => 'Text',
            default => "/gscmnt/sata921/info/medseq/make_tier_bed_files/NCBI-human-build36/tier4.bed",
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
    unless(-s $self->variant_bed_file) {
        $self->error_message("The variant file you supplied: " . $self->variant_bed_file . " appears to be 0 size. You need computer more better.");
        return;
    }
    my ($variant_filename, $directory, undef) = fileparse($self->variant_bed_file); 

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
    
    my $tier1_temp;
    my $tier2_temp;
    my $tier3_temp;
    my $tier4_temp;

    # This temp file is created in order to work around the issue with bedtools where 
    my $input_file_temp;

    if($self->indels){
        $input_file_temp = Genome::Utility::FileSystem->create_temp_file_path;
        $self->modify_insertions($self->variant_bed_file, $input_file_temp, '-');

        ####pindel 0 size insertion hack####i
        $tier1_temp = Genome::Utility::FileSystem->create_temp_file_path;
        $tier2_temp = Genome::Utility::FileSystem->create_temp_file_path;
        $tier3_temp = Genome::Utility::FileSystem->create_temp_file_path;
        $tier4_temp = Genome::Utility::FileSystem->create_temp_file_path;
    } else {
        $input_file_temp = $self->variant_bed_file; 
        $tier1_temp = $self->tier1_output;
        $tier2_temp = $self->tier2_output;
        $tier3_temp = $self->tier3_output;
        $tier4_temp = $self->tier4_output;
    }

    $input_file_temp = $self->tier($input_file_temp, $self->_tier1_bed,$tier1_temp,1);
    $input_file_temp = $self->tier($input_file_temp, $self->_tier2_bed,$tier2_temp,2);
    $input_file_temp = $self->tier($input_file_temp, $self->_tier3_bed,$tier3_temp,3);
    $input_file_temp = $self->tier($input_file_temp, $self->_tier4_bed,$tier4_temp,4);

    if($self->indels){
        $tier4_temp = $input_file_temp;
        $self->modify_insertions($tier1_temp, $self->tier1_output, "+"); 
        $self->modify_insertions($tier2_temp, $self->tier2_output, "+");
        $self->modify_insertions($tier3_temp, $self->tier3_output, "+");
        $self->modify_insertions($tier4_temp, $self->tier4_output, "+");
    }
    return 1;
}

sub tier {
    my $self = shift;
    my ($input,$tier_bed,$tier_output,$t) = @_;
    my $exclusive_list = Genome::Utility::FileSystem->create_temp_file_path if $self->exclusive_tiering;
    unless(($t==4)&&($self->exclusive_tiering)){
        unless($self->intersect_bed($input,$tier_bed,$tier_output)){
            $self->error_message("Couldn't complete intersectBed call for tier $t");
            die $self->error_message;
        }
        if($self->exclusive_tiering){
            unless($self->intersect_bed_v($input,$tier_bed,$exclusive_list)){
                $self->error_message("Couldn't complete intersectBed -v call for tier $t");
                die $self->error_message;
            }
            $input = $exclusive_list;
        }
    }
    if($t==4 && (not $self->indels && $self->exclusive_tiering)){
        copy($input,$self->tier4_output);
    }
    return $input;
}

sub intersect_bed {
    my $self = shift;
    my $a = shift;
    my $b = shift;
    my $output = shift;
    my $result;
    if(-s $a){
        my $cmd = $self->intersect_bed_bin_location." -wa -u -a " . $a . " -b " . $b . " > $output";  
        $result = Genome::Utility::FileSystem->shellcmd(
            cmd          => $cmd,
            input_files  => [ $a ],
            output_files => [ ],
            skip_if_output_is_present => 0
        );
    } else {
        $result = $self->touch($output);
    }
    return $result;
}

sub intersect_bed_v {
    my $self = shift;
    my $a = shift;
    my $b = shift;
    my $output = shift;
    my $cmd = $self->intersect_bed_bin_location." -wa -v -a " . $a . " -b " . $b . " > $output";  
    my $result = Genome::Utility::FileSystem->shellcmd(
        cmd          => $cmd,
        input_files  => [ $a ],
        output_files => [ ],
        skip_if_output_is_present => 0
    );
    return $result;
}

sub modify_insertions {
    my $self=shift;
    my $input_file=shift;
    my $output_file=shift;
    my $mode = shift;
    my $ifh = Genome::Utility::FileSystem->open_file_for_reading($input_file);
    my $ofh = Genome::Utility::FileSystem->open_file_for_writing($output_file);
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

sub touch {
    my $self = shift;
    my $file = shift;

    my $cmd = "touch $file";

    my $result = Genome::Utility::FileSystem->shellcmd( cmd => $cmd);

    return $result;
}
