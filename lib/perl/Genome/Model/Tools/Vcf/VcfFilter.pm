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
        bed_input => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'filter file is in bed (0-based format). Default false (expects 1-based coordinates)',
            default=>0,
        },
        variant_type => {
            is => 'Text',
            is_optional => 1,
            doc => 'apply filters only to variants of this type (usually "SNP" or "INDEL")',
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

    my $bgzip_in = ($vcf_file =~ m/gz$/) ? 1 : 0;
    my $bgzip_out = ($output_file =~ m/gz$/) ? 1 : 0;

    # first, read the filter file and store the locations
    my %filter;
    my $filter_fh = Genome::Sys->open_file_for_reading($filter_file); #IO::File->new( $filter_file ) || die "can't open vcf file\n";
    while( my $line = $filter_fh->getline ) {
        chomp($line);

        #skip header lines
        next if ($line =~ /^#/);

        my @fields = split("\t",$line);
        if($self->bed_input) {
            unless($fields[3] =~ /\*/) { #in bed, this would be an insertion or deletion and we should not naively ++ the start
                $fields[1]+=1;
            }
        }
        my $key = $fields[0] . ":" . $fields[1];

        #add this filter to the hash
        $filter{$key} = 0;
    }
    $filter_fh->close;

    #open the output file
    my $outfile = ($bgzip_out) ? Genome::Sys->open_gzip_file_for_writing($output_file) : Genome::Sys->open_file_for_writing($output_file);

    #read the vcf
    my $inFh = ($bgzip_in) ? Genome::Sys->open_gzip_file_for_reading($vcf_file) : Genome::Sys->open_file_for_reading($vcf_file);

    my $found_pass_line = 0;
    my $found_format_lines = 0;
    my $done_with_header = 0;
    my $found_ft_header = 0;

    #if this is a header line
    while(!$done_with_header) {
        my $line = $inFh->getline;
        chomp($line);
        if ($line =~ /^##/){
            if ($line =~/^##FILTER=<ID=PASS/){
                $found_pass_line = 1;
            }

            # if this is the first FORMAT line, drop our
            # filter headers into the VCF here
            if ($line =~ /^##FORMAT/ && $found_format_lines == 0){
                unless ($found_pass_line){
                    print $outfile "##FILTER=<ID=PASS,Description=\"Passed all filters\">" . "\n";
                }

                print $outfile "##FILTER=<ID=" . $filter_name . ",Description=\"" . $filter_description . "\">" . "\n";
                $found_format_lines = 1;
            }
            print $outfile $line . "\n";

            if ($line =~ /^##FILTER=<ID=FT,/) {
                $found_ft_header = 1;
            }
        } elsif ($line =~ /^#CHROM/){
            $done_with_header = 1;
            unless ($found_ft_header) {
                print $outfile '##FORMAT=<ID=FT,Number=1,Type=Integer,Description="Filter Status">' . "\n";
            }
            print $outfile $line . "\n";
        } else {
            die $self->error_message("Failed to find the final header line");
        }
    }

    while( my $line = $inFh->getline ) {
        my $remove_line = 0;
        chomp($line);

        my @fields = split("\t",$line);

        # if this is not of the correct variant type, skip it
        if (defined($variant_type) && !($fields[7] =~ /VT=$variant_type/)){
            print $outfile $line . "\n";
        } else {

            # only check the filters if this snv hasn't already been filtered
            # (is passing). If it has been filtered, then accept the prior filter
            # and move on
            my $filter_value;
            if (($fields[6] eq "") || ($fields[6] eq "PASS") || ($fields[6] eq ".")){

                my $key = $fields[0] . ":" . $fields[1];

                if ($filter_keep){
                    if (exists($filter{$key})){
                        $filter_value = "PASS";
                    } else {
                        if($remove_filtered_lines){
                            $remove_line = 1;
                        } else {
                            $filter_value = $filter_name;
                        }
                    }
                } else {
                    if (exists($filter{$key})){
                        if($remove_filtered_lines){
                            $remove_line = 1;
                        } else {
                            $filter_value = $filter_name;
                        }
                    } else {
                        $filter_value = "PASS";
                    }
                }
                $fields[6] = $filter_value;
            } else {
                $filter_value = $fields[6];
            }

            # Add a FT field with the same information as the filter field
            my $format_field = $fields[8];
            my @format_keys = split ":", $format_field;
            # Find the FT field if it exists
            my $ft_index;
            for (my $i = 0; $i <= $#format_keys; $i++) {
                if ($format_keys[$i] eq "FT") {
                    $ft_index = $i;
                }
            }

            # If FT was not previously present, add it to the format field
            unless ($ft_index) {
                $fields[8] = join(":", (@format_keys, "FT") );
            }

            # For each sample present in the file, either replace the old FT value if one was present or insert a new one
            for (my $sample_index = 9; $sample_index <= $#fields; $sample_index++) {
                my $sample_field = $fields[$sample_index];
                if ($ft_index) {
                    my @sample_fields = split ":", $sample_field;
                    $sample_fields[$ft_index] = $filter_value;
                    $fields[$sample_index] = join(":", @sample_fields);
                } else {
                    $fields[$sample_index] = join(":", ($fields[$sample_index], $filter_value) );
                }
            }

            #output the line
            unless($remove_line){
                print $outfile join("\t", @fields) . "\n";
            }
        }
    }
    $outfile->close;
    $inFh->close;

    return 1;
}
