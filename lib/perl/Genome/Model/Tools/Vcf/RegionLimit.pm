package Genome::Model::Tools::Vcf::RegionLimit;

use strict;
use warnings;
use Genome;
use File::stat;
use IO::File;
use File::Basename;
use File::Copy;
use Getopt::Long;
use FileHandle;

class Genome::Model::Tools::Vcf::RegionLimit {
    is => 'Command',
    has_input => [
        output_file => {
            is => 'Text',
            is_output => 1,
            is_optional => 0,
            doc => "The limited vcf output path",
        },
        vcf_file => {
            is => 'Text',
            is_optional => 0,
            is_output => 1,
            doc => "The source vcf to be limited",
        },
        region_bed_file => {
            is => 'Text',
            is_output => 1,
            doc => 'The bed coordinates of regions to limit the vcf to',
        },
        roi_name => {
            is => 'Text',
            doc => 'Region of Interest Set Name, this will be added as a tag in the vcf header is specified.',
            is_optional => 1,
        },
        wingspan => {
            is => 'Text',
            is_output => 1,
            doc => 'This is the amount of bases to include on either side of each region',
            default => 0,
        },
    ],
};


sub help_synopsis {
    <<'HELP';
Use this to limit a vcf file to only those regions in your limiting bed file. Specify wingspan to pad your regions.
HELP
}

sub help_detail {
    <<'HELP';
Use this to limit a vcf file to only those regions in your limiting bed file. Specify wingspan to pad your regions.
HELP
}

sub execute {
    my $self = shift;
    my $vcf_file = $self->vcf_file;
    my $output_file = $self->output_file;
    my $bed_file = $self->region_bed_file;
    my $wingspan = $self->wingspan;

    my $output_fh = Genome::Sys->open_gzip_file_for_writing($output_file);
    my $vcf_fh = Genome::Sys->open_gzip_file_for_reading($vcf_file);

    $self->print_header($output_fh,$vcf_fh);
    $output_fh->close;
    $vcf_fh->close;

    my $window_bed_cmd = "bash -c \"windowBed -a ".$bed_file." -b <(zcat ".$vcf_file.") -w ".$wingspan." | cut -f5- | bgzip -c >> ".$output_file."\"";
    my $result = Genome::Sys->shellcmd( cmd => $window_bed_cmd );
    unless($result){
        die $self->error_message("Could not complete windowBed command.");
    }
    my $sort_vcf_cmd = "bash -c \"joinx sort <(zcat ".$output_file.") | bgzip -c > ".$output_file.".tmp \"";
    my $sort_result = Genome::Sys->shellcmd( cmd => $sort_vcf_cmd );
    unless($sort_result){
        die $self->error_message("Unable to complete sorting VCF output");
    }
    if(-s $output_file.".tmp"){
        move( $output_file.".tmp", $output_file);
        unlink( $output_file.".tmp");        
    } else {
        die $self->error_message("Sorted output, but could not locate intermediate temp file: ".$output_file.".tmp");
    }
    return 1;
}

sub print_header {
    my $self = shift;
    my $output_fh = shift;
    my $vcf_fh = shift;

    my $line = $vcf_fh->getline;
    chomp $line;
    while($line =~ m/^##/){
        print $output_fh $line."\n";
        $line = $vcf_fh->getline;
        chomp $line;
    }
    if($line =~ m/^#/){
        if($self->roi_name){
            my $roi = $self->roi_name;
            print $output_fh "##regionOfInterestSetName=".$roi."\n";
        }
        print $output_fh $line."\n";
    } else {
        die $self->error_message("Encountered unexpected trouble parsing the header.");
    }

    return 1;
}

1;
