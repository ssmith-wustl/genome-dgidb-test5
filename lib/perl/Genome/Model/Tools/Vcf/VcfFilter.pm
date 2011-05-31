package Genome::Model::Tools::Vcf::VcfFilter;
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

class Genome::Model::Tools::Vcf::VcfFilter {
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

        filter_file => {
            is => 'Text',
            doc => "files containing SNVs to be filtered (assumes first col CHR, second col POS",
            is_optional => 1,
            default => "",
        },

        filter_keep => {
            is => 'Boolean',
            doc => "the filter file contains variants that *passed* filters (all *other* SNVs will be marked invalid). If false, the opposite is assumed - the file contains variants that did not pass filters",
            is_optional => 1,
            default => 0,
        },

        filter_name => {
            is => 'Text',
            doc => "name to add to the FILTER field for variants newly marked filtered",
            is_optional => 1,
            default => "",
        },

        filter_description => {
            is => 'Text',
            doc => "description of the FILTER for the header",
            is_optional => 1,
            default => "",
        },

        remove_filtered_lines => {
            is => 'Boolean',
            is_optional => 1,
            default => 0 ,
            doc => 'remove the filtered lines, as opposed to marking them as non-passing in the VCF',
        },

        variant_type => {
            is => 'Text',
            is_optional => 1,
            doc => 'apply filters only to variants of this type (usually \"SNV\" or \"INDEL\")',
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
    my $filter_file = $self->filter_file;
    my $filter_keep = $self->filter_keep;
    my $filter_name = $self->filter_name;
    my $filter_description = $self->filter_description;
    my $remove_filtered_lines = $self->remove_filtered_lines;
    my $variant_type = $self->variant_type;


    # first, read the filter file and store the locations
    my %filter;
    my $inFh = IO::File->new( $filter_file ) || die "can't open vcf file\n";
    while( my $line = $inFh->getline )
    {
        chomp($line);

        #skip header lines
        next if ($line =~ /^#/);

        my @fields = split("\t",$line);
        my $key = $fields[0] . ":" . $fields[1];

        #add this filter to the hash
        $filter{$key} = 0;
    }
    close($inFh);



    #open the output file
    open(OUTFILE, ">$output_file") or die "Can't open output file: $!\n";


    #read the vcf
    $inFh = IO::File->new( $vcf_file ) || die "can't open vcf file\n";
    my $found_pass_line = 0;
    my $found_format_lines = 0;
    while( my $line = $inFh->getline )
    {
        my $remove_line = 0;

        chomp($line);
        #if this is a header line
        if ($line =~ /^#/){
            if ($line =~/^##FILTER=<ID=PASS/){
                $found_pass_line = 1;
            }

            # if this is the first FORMAT line, drop our
            # filter headers into the VCF here
            if ($line =~ /^##FORMAT/ && $found_format_lines == 0){
                unless ($found_pass_line){
                    print OUTFILE "##FILTER=<ID=PASS,Description=\"Passed all filters\">" . "\n";
                }

                print OUTFILE "##FILTER=<ID=" . $filter_name . ",Description=\"" . $filter_description . "\">" . "\n";
                $found_format_lines = 1;
            }
            print OUTFILE $line . "\n";


        } else {   #else we're in body of the vcf, check it against the filters

            my @fields = split("\t",$line);


            # if this is not of the correct variant type, skip it
            if (defined($variant_type) && !($fields[7] =~ /VT=$variant_type/)){
                print OUTFILE $line . "\n";
            } else {

                # only check the filters if this snv hasn't already been filtered
                # (is passing). If it has been filtered, then accept the prior filter
                # and move on
                if (($fields[6] eq "") || ($fields[6] eq "PASS") || ($fields[6] eq ".")){

                    my $key = $fields[0] . ":" . $fields[1];

                    if ($filter_keep){
                        if (exists($filter{$key})){
                            $fields[6] = "PASS";
                        } else {
                            if($remove_filtered_lines){
                                $remove_line = 0;
                            } else {
                                $fields[6] = $filter_name;
                            }
                        }
                    } else {
                        if (exists($filter{$key})){
                            if($remove_filtered_lines){
                                $remove_line = 0;
                            } else {
                                $fields[6] = $filter_name;
                            }
                        } else {
                            $fields[6] = "PASS";
                        }
                    }
                }


                #output the line
                unless($remove_line){
                    print OUTFILE join("\t", @fields) . "\n";
                }
            }
        }        
    }
    close(OUTFILE);
    
    return 1;
}
