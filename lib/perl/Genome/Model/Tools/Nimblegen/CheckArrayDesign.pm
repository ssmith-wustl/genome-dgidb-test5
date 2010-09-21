package Genome::Model::Tools::Nimblegen::CheckArrayDesign;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Nimblegen::CheckArrayDesign {
    is => 'Command',
    has => [
    nimblegen_probe_bedfile => {
        type => 'String',
        is_optional => 0,
        doc => 'Zip file provided by nimblegen after designing your array',
    },
    design_files => {
        type => 'Comma-delimited String',
        is_optional => 0,
        doc => 'A comma-delimited list of files that went into the array design',
    },
    design_summary_outfile => {
        type => 'String',
        is_optional => 0,
        doc => 'An output summary file giving the number of input sites that came from each array design input file as compared to the number of these respective sites covered in the array design.',
    },
    ]
};

sub execute {
    my $self = shift;
    $DB::single = 1;

    #parse inputs
    my $probe_bed = $self->nimblegen_probe_bedfile;
    my @design_files = split /,/,$self->design_files;
    my $summary_file = $self->design_summary_outfile;

    #put the tiled regions from the probe set into a hash
    my %probes;
    my $probe_fh = new IO::File $probe_bed,"r";
    my $track_found = 0;

    while (my $line = $probe_fh->getline) {
        if ($line =~ /track name=tiled_region description="NimbleGen Tiled Regions"/i) {
            $track_found = 1;
            next;
        }
        if ($track_found) {
            my ($chr,$start,$stop) = split /\t/,$line;
            my $modstart = $start - 50;
            my $modstop = $stop + 50;
            $probes{$chr}{$modstart} = $modstop;
            #$probes{$chr}{$start} = $stop;
        }
    }
    $probe_fh->close;

    #set up summary filehandle and header
    my $sum_fh = new IO::File $summary_file,"w";
    print $sum_fh "Design_File\t#_Sites\t#_Tiled_Sites\t%_Tiled_Sites\n";


    #loop through files, writing outputs as you go
    for my $file (@design_files) {
        my $infh = new IO::File $file,"r";

        #set up file to catch uncovered (untiled) sites
        my $uncovered_file = $file . ".not_tiled";
        my $uncov_fh = new IO::File $uncovered_file,"w";

        #variables to record statistics for summary file
        my $sites;
        my $covered_sites;

        while (my $line = $infh->getline) {
            $sites++;
            chomp $line;
            my ($chr,$start,$stop) = split /\t/,$line;

            #find out if site was tiled
            my $site_is_tiled = 0;
            for my $probe_start (keys %{$probes{$chr}}) {
                my $probe_stop = $probes{$chr}{$probe_start};
                if ($start <= $probe_stop && $stop >= $probe_start) {
                    $covered_sites++;
                    $site_is_tiled++;
                    last;
                }
            }

            #actions to take if site was found to not be tiled
            unless ($site_is_tiled) {
                print $uncov_fh "$line\n";
            }
        }
        $infh->close;
        $uncov_fh->close;

        #add line to summary file for this design file
        my $percent_tiled = $covered_sites / $sites * 100;
        my $percent = sprintf("%.1f",$percent_tiled);
        print $sum_fh "$file\t$sites\t$covered_sites\t$percent\n";
    }
    return 1;
}

sub help_brief {
    "Check nimblegen array design. Print uncovered sites."
}

sub help_detail {
    "This script takes in a Nimblegen-designed probe .bed file, and also a comma-delimited list of input files used to make the original probe design sent to nimblegen, and does two things: 1) The script checks to see how many of the sites sent to Nimblegen ended up on the probe, and prints out a summary file listing the filename of the design file, along with the number of sites in the design file, and then the number and percentage that actually ended up being tiled. 2) The script also takes the original design file and places a file directly next to it called design_filename.not_tiled which contains all of the sites from the original design file that did not end up tiled on the probe .bed file. Enjoy."
}

1;
