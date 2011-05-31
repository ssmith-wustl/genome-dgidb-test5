package Genome::Model::Tools::Vcf::VcfMerge;

use strict;
use warnings;
use Genome;
use File::stat;
use IO::File;
use File::Basename;
use Getopt::Long;
use FileHandle;

class Genome::Model::Tools::Vcf::VcfMerge {
    is => 'Command',
    has => [
        output_file => {
            is => 'Text',
            is_output => 1,
            is_optional => 0,
            doc => "Output merged VCF",
        },

        vcf_files => {
            is => 'Text',
            is_output => 1,
            is_optional => 0,
            doc => "comma-seperated list of VCF files containing mutations from the same sample",
        },

        source_ids => {
            is => 'Text',
            is_output => 1,
            is_optional => 1,
            doc => "given a comma-separated list of ids used to identify the source of the input VCF files. (i.e. GATK, samtools, varScan), will label the source in the info field",
        },


	],
};


sub help_brief {                            # keep this to just a few words <---
    "Merge multiple VCFs - keep the quality scores from files in desc order"
}


sub help_synopsis {
<<'HELP';
Merge multiple VCFs - keep the quality scores from files in desc order
HELP
}

sub help_detail {                  # this is what the user will see with the longer version of help. <---
<<'HELP';
Merge multiple VCFs. For identical calls made by different algorithms, merge them, keeping the scores from the file that is listed first in the vcf_files string.
HELP
}

###############

sub execute {                               # replace with real execution logic.
    my $self = shift;

    my $vcf_files = $self->vcf_files;
    my $output_file = $self->output_file;
    my $source_ids = $self->source_ids;

    my @vcffiles = split(",",$vcf_files);
    if (@vcffiles < 1){
        die ("requires multiple VCF files to be input (comma-sep)")
    }

    my @vcfnames;
    if(defined($source_ids)){
        @vcfnames = split(",",$source_ids);
        if (@vcffiles != @vcfnames){
            die ("requires a source id for each input VCF file")
        }
    }

    my %varHash;
    my %infoHash;
    my @header;
    #hash the first file
    my $inFh = IO::File->new( $vcffiles[0] ) || die "can't open file\n";
    while(my $line = $inFh->getline )
    {
        chomp($line);
        if ($line =~ /^\#/){
            if ($line =~ /##INFO=\<ID\=(\w+),/){
                $infoHash{$1} = $line
            }
            push(@header,$line);
            next;
        } 
        
        my @col = split("\t",$line);

        my $chr = $col[0];
        #replace X and Y for sorting
        $chr = "23" if $col[0] eq "X";
        $chr = "24" if $col[0] eq "Y";
        $chr = "25" if $col[0] eq "MT";
        my $id = $chr . ":" . $col[1] . ":" . $col[3] . ":" . $col[4];

        #add source id
        if(defined($source_ids)){
            if($col[7] eq "."){
                $col[7] = "VC=" . $vcfnames[0];
            } else {
                $col[7] = $col[7] . ";VC=" . $vcfnames[0];
            }
        }
        
        @{$varHash{$id}} = @col;
    }
    close($inFh);


    my @newInfo;
    if(defined($source_ids)){
        push(@newInfo,"##INFO=<ID=VC,Number=1,Type=String,Description=\"Variant caller\">");
    }

    #add data from subsequent files if data does not exist in first file
    for(my $i=1; $i<@vcffiles; $i++){
        $inFh = IO::File->new( $vcffiles[$i] ) || die "can't open file\n";

        while(my $line = $inFh->getline )
        {
            chomp($line);

            if ($line =~ /^#/){
                if ($line =~ /##INFO=\<ID\=(\w+),/){
                    unless (exists($infoHash{$1})){
                        push(@newInfo,$line)
                    }
                }                    
                next;
            } 

            my @col = split("\t",$line);
            my $chr = $col[0];

            next if($chr =~ /NT/);

            #replace X and Y for sorting
            $chr = "23" if $col[0] eq "X";
            $chr = "24" if $col[0] eq "Y";
            $chr = "25" if $col[0] eq "MT";

            my $id = $chr . ":" . $col[1] . ":" . $col[3] . ":" . $col[4];

            if(exists($varHash{$id})){
                if(defined($source_ids)){
                    @{$varHash{$id}}[7] = @{$varHash{$id}}[7] . "," . $vcfnames[$i];
                }
            } else {
                #add source id
                if(defined($source_ids)){
                    if($col[7] eq "."){
                        $col[7] = "VC=" . $vcfnames[$i];
                    } else {
                        $col[7] = $col[7] . ";VC=" . $vcfnames[$i];
                    }
                }

                #add to the hash
                @{$varHash{$id}} = @col;
            }
        }
    }



    #sort by chr, start for clean output
    sub keySort{
        my($x,$y) = @_;
        my @x1 = split(":",$x);
        my @y1 = split(":",$y);
        return($x1[0] <=> $y1[0] || $x1[1] <=> $y1[1])
    }
    my @sortedKeys = sort { keySort($a,$b) } keys %varHash;

    #output
    open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";


    #first the headers
    foreach my $line (@header){        
        if ($line =~ /^#CHROM/){
            #dump the new info lines just before the column header
            foreach my $line2 (@newInfo){
                print OUTFILE $line2 . "\n";
            }
        }
        
        #just output
        print OUTFILE $line . "\n";

    }
    
    #then the body
    foreach my $key (@sortedKeys){
        print OUTFILE join("\t",@{$varHash{$key}}) . "\n";
    }

    return 1;
}

