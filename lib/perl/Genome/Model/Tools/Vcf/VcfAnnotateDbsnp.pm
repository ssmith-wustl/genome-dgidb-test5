package Genome::Model::Tools::Vcf::VcfAnnotateDbsnp;
##########################################################################
# Given a VCF file and a list of things to filter, removes them or
# marks them appropriately in the VCF file
#
#
#       AUTHOR:         Chris Miller (cmiller@genome.wustl.edu)
#
#       CREATED:        05/04/2011 by CAM
#       MODIFIED:
#
#       NOTES:
#
###########################################################################
use strict;
use warnings;
use Genome;
use File::stat;
use IO::File;
use File::Basename;
use Getopt::Long;
use FileHandle;
use POSIX qw(log10);
use POSIX qw(strftime);
use List::MoreUtils qw(firstidx);
use List::MoreUtils qw(uniq);

class Genome::Model::Tools::Vcf::VcfAnnotateDbsnp {
    is => 'Command',
    has => [
        output_file => {
            is => 'Text',
            is_output => 1,
            doc => "filtered VCF file",
            is_optional => 0,
        },

        vcf_file => {
            is => 'Text',
            is_input => 1,
            doc => "mutations in Vcf format",
            is_optional => 0,
        },

        dbsnp_file => {
            is => 'Text',
            doc => "files containing dbsnp annotations",
            is_optional => 0,
        },

        ],
};


sub help_brief {                            # keep this to just a few words <---
    "apply filter labels to a VCF file"
}


sub help_synopsis {
<<'HELP';
    apply filter labels to a VCF file
HELP
}

sub help_detail {                  # this is what the user will see with the longer version of help. <---
<<'HELP';

    Takes a VCF and a file containing filtered output, then annotates the VCF with the filter names, and adds the filter info  to the header
HELP
}




################################################################################################
# Execute - the main program logic
################################################################################################

sub execute {
    my $self = shift;
    my $output_file = $self->output_file;
    my $vcf_file = $self->vcf_file;
    my $dbsnp_file = $self->dbsnp_file;



    #open the output file
    open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";

    my %posHash;

    #read the vcf
    my $inFh = IO::File->new( $vcf_file ) || die "can't open vcf file\n";
    my $found_pass_line = 0;
    my $found_format_lines = 0;
    while( my $line = $inFh->getline )
    {
        my $remove_line = 0;

        chomp($line);
        #if this is a header line
        if ($line =~ /^#/){
            print OUTFILE $line . "\n";
        } else {   #else we're in body of the vcf, hash the data

            my @fields = split("\t",$line);

            my $chr = $fields[0];
            $chr = "23" if $chr eq "X";
            $chr = "24" if $chr eq "Y";
            $chr = "25" if $chr eq "MT";

            my $key = $chr . ":" . $fields[1];
            push(@{$posHash{$key}}, @fields);
        }

    }

    #now, go through the dbsnp file matching on position:

    print STDERR "adding dbSNP info - this will take a few minutes\n";
    my $inFh2 = IO::File->new( $dbsnp_file ) || die "can't open file\n";
    while( my $line = $inFh2->getline )
    {
        unless($line =~ /^#/){
            chomp($line);
            my @fields = split("\t",$line);
            if($fields[11] eq "single"){

                $fields[1] =~ s/chr//;

                #replace X and Y for sorting
                my $chr = $fields[1];
                $chr = "23" if $chr eq "X";
                $chr = "24" if $chr eq "Y";
                $chr = "25" if $chr eq "MT";

                #ucsc is zero-based, so we adjust
                my $pos = $fields[2]+1;
                my $key = $chr . ":" . $pos;

                #if the line matches this dbsnp position
                if(exists($posHash{$key})){
                    #add to id field
                    if (@{$posHash{$key}}[2] eq "."){
                        @{$posHash{$key}}[2] = "";
                    } elsif (!(@{$posHash{$key}}[2] eq "")) {
                        @{$posHash{$key}}[2] = @{$posHash{$key}}[2] . ";";
                    }
                    @{$posHash{$key}}[2] = @{$posHash{$key}}[2] . $fields[4];
                }
            }
        }
    }

    sub keySort{
        my($x,$y) = @_;
        my @x1 = split(":",$x);
        my @y1 = split(":",$y);
        return($x1[0] <=> $y1[0] || $x1[1] <=> $y1[1]);
    }
    my @sortedKeys = sort { keySort($a,$b) } keys %posHash;

    foreach my $key (@sortedKeys){
        print OUTFILE join("\t",@{$posHash{$key}}) . "\n";
    }

    close(OUTFILE);
    return 1;
}
