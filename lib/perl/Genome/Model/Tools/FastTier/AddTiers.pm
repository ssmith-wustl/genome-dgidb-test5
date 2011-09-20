package Genome::Model::Tools::FastTier::AddTiers;

use warnings;
use strict;
use Genome;
use IO::File;


class Genome::Model::Tools::FastTier::AddTiers {
    is => 'Command',
    has => [
	build => {
	    is => 'Integer',
	    is_optional => 1,
	    doc => 'Genome build to use (accepts 36 or 37)',
            default => '36',
	},
        
        input_file => {
            is => 'String',
            is_optional => 0,
            is_input => 1,
            doc => 'input file (assumes the first 3 columns are Chr, Start, Stop)',
        },

        input_is_maf => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'assumes the input file is a maf, and instead uses columns 5,6,7 for Chr, Start, Stop',
        },

        output_file => {
            is => 'String',
            is_optional => 0,
            is_input => 1,
            doc => 'output file is equivalent to the input file with tier info added as an additional column',
        },

        tier_file_location =>{
            is => 'String',
            is_optional => 1,
            is_input => 1,
            doc => 'use this to override the default (v3) tiering files',
        },

        tiering_version =>{
            is => 'String',
            is_optional => 1,
            is_input => 1,
            doc => 'use this to override the default (v3) tiering version',
        },
    ]
};

sub help_brief {
    "add tiering information to an existing file"
}

sub help_detail {
    "add tiering information to an existing file"
}


sub execute {

    my $self = shift;
    my $input_file = $self->input_file;
    my $output_file = $self->output_file;
    my $input_is_maf = $self->input_is_maf;
    my $build = $self->build;
    my $tier_file_location = $self->tier_file_location;
    my $tiering_version = $self->tiering_version;

    unless(defined($tier_file_location)){
        if($build == 36){
            $tier_file_location = "/gscmnt/ams1100/info/model_data/2771411739/build102550711/annotation_data/tiering_bed_files_v3";
        } elsif ($build == 37){
            $tier_file_location = "/gscmnt/ams1102/info/model_data/2771411739/build106409619/annotation_data/tiering_bed_files_v3";
        } else {
            die("only supports builds 36 or 37");
        }
    }
    

    #create a tmp dir for the output
    my $tempdir = Genome::Sys->create_temp_directory();
    unless($tempdir) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    open(OUTFILE,">$tempdir/temp.bed") || die "can't open temp segs file for writing ($tempdir/temp.bed)\n";
      
    
    #write out the temporary bed file
    my $inFh = IO::File->new( $input_file ) || die "can't open input file\n";    
    while( my $line = $inFh->getline )
    {
        chomp($line);
        my @F = split("\t",$line);
        
        next if ($line =~ /^Hugo_/ || $line =~ /Chromosome/);

        if($input_is_maf){
            print OUTFILE join("\t",($F[4], $F[5]-1, $F[6])) . "\n";
        } else {
            print OUTFILE join("\t",($F[0], $F[1]-1, $F[2])) . "\n";
        }
    }
    close($inFh);
    close(OUTFILE);

    #sort the bed file
    my $cmd = "/gscuser/cmiller/usr/bin/bedsort $tempdir/temp.bed >$tempdir/temp.bed.sorted";
    my $return = Genome::Sys->shellcmd(
        cmd => "$cmd",
        );
    unless($return) {
        $self->error_message("Failed to execute: Returned $return");
        die $self->error_message;
    }

    #annotate that bed file
    $cmd = "gmt fast-tier fast-tier --tier-file-location $tier_file_location --variant-bed-file $tempdir/temp.bed.sorted";
    if(defined($tiering_version)){
        $cmd = $cmd . " --tiering-version $tiering_version";
    }

    $return = Genome::Sys->shellcmd(
    cmd => "$cmd",
    );
    unless($return) {
        $self->error_message("Failed to execute: Returned $return");
        die $self->error_message;
    }


    #now read in the tier files, match them up with the original bed
    my %tierhash;
    #read in the tier files
    my @tiers = ("tier1","tier2","tier3","tier4");
    foreach my $tier (@tiers){
        my $inFh = IO::File->new( "$tempdir/temp.bed.sorted.$tier" ) || die "can't open $tier file\n";
        while( my $line = $inFh->getline )
        {
            chomp($line);
            my @F = split("\t",$line);
            my $key = $F[0] . ":" . ($F[1]+1) . ":" . $F[2];
            $tierhash{$key} = $tier        
        }
    }
 
    open(OUTFILE1,">$output_file") || die "can't open outfile for writing ($output_file)\n";

    #match up the tiers with the original file
    $inFh = IO::File->new( $input_file ) || die "can't open input file\n";
    while( my $line = $inFh->getline )
    {
        #skip header
        if (($line=~/^Chr/) || ($line =~ /^#/)){
            print OUTFILE1 $line;
            next;
        }
        
        chomp($line);
        my @F = split("\t",$line);
        my $key;
        if($input_is_maf){
            $key = $F[4] . ":" . $F[5] . ":" . $F[6];
        } else {
            $key = $F[0] . ":" . $F[1] . ":" . $F[2];
        }
        push(@F,$tierhash{$key});
        print OUTFILE1 join("\t",@F) . "\n";
    }
    close(OUTFILE1);

    return 1;
}
