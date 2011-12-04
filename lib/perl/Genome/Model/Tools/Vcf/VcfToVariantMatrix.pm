package Genome::Model::Tools::Vcf::VcfToVariantMatrix;

use strict;
use warnings;
use Genome;
use IO::File;
use Getopt::Long;
use FileHandle;

class Genome::Model::Tools::Vcf::VcfToVariantMatrix {
    is => 'Command',
    has => [
        output_file => {
            is => 'Text',
            is_output => 1,
            is_optional => 0,
            doc => "Output variant matrix format",
        },
        vcf_file => {
            is => 'Text',
            is_optional => 0,
            doc => "Merged Multisample Vcf containing mutations from all samples",
        },
        positions_file => {
            is => 'Text',
            is_optional => 1,
            doc => "Limit Variant Matrix to Sites - File format chr\\tpos\\tref\\talt",
        },
        bed_roi_file => {
            is => 'Text',
            is_optional => 1,
            doc => "Limit Variant Matrix to Sites Within an ROI - Bed format chr\\tstart\\tstop\\tref\\talt",
        },
        project_name => {
            is => 'Text',
            is_optional => 1,
            doc => "Name of the project, will be inserted into output file cell A1",
            default => "Variant_Matrix",
        },
    ],
};


sub help_brief {
    "Input Merged Multisample Vcf, Output Variant Matrix for Statistical Genetics Programs"
}


sub help_synopsis {
    <<'HELP';
Input Merged Multisample Vcf, Output Variant Matrix for Statistical Genetics Programs
HELP
}

sub help_detail {
    <<'HELP';
Input Merged Multisample Vcf, Output Variant Matrix for Statistical Genetics Programs
HELP
}

###############
sub execute {                               # replace with real execution logic.
    my $self = shift;
    my $vcf_file = $self->vcf_file;
    my $output_file = $self->output_file;
    my $project_name = $self->project_name;
    my $roi_bed = $self->bed_roi_file;

    my $fh = Genome::Sys->open_file_for_writing($output_file);

    my $inFh_positions;
    my %positions_selection_hash;
    if ($self->positions_file) {
        print "Loading Position Restriction File\n";
        my $positions_file = $self->positions_file;
        $inFh_positions = IO::File->new( $positions_file ) || die "can't open $positions_file\n";
        while(my $line = $inFh_positions->getline ) {
            chomp($line);
            my ($chr, $pos, $ref, $alt) = split(/\t/, $line);
            my $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt";
            $positions_selection_hash{$variant_name}++;
        }
    }

    my ($tfh,$temp_path);
    if ($self->bed_roi_file) {
        ## Build temp file for vcf limited to roi ##
        ($tfh,$temp_path) = Genome::Sys->create_temp_file;
        unless($tfh) {
            $self->error_message("Unable to create temporary file $!");
            die;
        }
        $temp_path =~ s/\:/\\\:/g;

        print "Loading Position Restriction File\n";

        my $header = `grep '^#' $vcf_file`;
        print $tfh "$header";
        my $intersect_bed_vcf = `intersectBed -a $vcf_file -b $roi_bed`;
        print $tfh "$intersect_bed_vcf";
        close ($tfh);
    }

    my $inFh;
    if ($self->bed_roi_file) {
        $inFh = IO::File->new( $temp_path ) || die "can't open file\n";
    }
    else {
        $inFh = IO::File->new( $vcf_file ) || die "can't open file\n";
    }

    print "Loading Genotype Positions from Vcf\n";
    my $header_line;
    my @sample_names;
    my %variant_hash;
    my %sample_hash;
    while(my $line = $inFh->getline ) {
        chomp($line);
        if ($line =~ /^\#\#/) {
            next;
        }
        elsif ($line =~ /^\#CHROM/) { #grab sample names off of the header line
            my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
            @sample_names = @samples;
            print $fh "$project_name";
            next;
        }

        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
        #current possible fields, Sept 2011: GT:GQ:DP:BQ:MQ:AD:FA:VAQ:FET
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype Quality">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Total Read Depth">
##FORMAT=<ID=BQ,Number=A,Type=Integer,Description="Average Base Quality corresponding to alleles 0/1/2/3... after software and quality filtering">
##FORMAT=<ID=MQ,Number=1,Type=Integer,Description="Average Mapping Quality">
##FORMAT=<ID=AD,Number=A,Type=Integer,Description="Allele Depth corresponding to alleles 0/1/2/3... after software and quality filtering">
##FORMAT=<ID=FA,Number=1,Type=Float,Description="Fraction of reads supporting ALT">
##FORMAT=<ID=VAQ,Number=1,Type=Integer,Description="Variant Quality">
##FORMAT=<ID=FET,Number=1,Type=String,Description="P-value from Fisher's Exact Test">

        #parse format line to find out where our pattern of interest is in the ::::: system
        my (@format_fields) = split(/:/, $format);
        my $gt_location; #genotype
        my $dp_location; #depth - this is not filled for vasily ucla files - this is currently unused down below
        my $gq_location; #genotype quality - this is only filled in washu vcf for samtools variants, not varscan and not homo ref - this is currrently unused down below
        my $count = 0;
        foreach my $format_info (@format_fields) {
            if ($format_info eq 'GT') {
                $gt_location = $count;
            }
            elsif ($format_info eq 'DP') {
                $dp_location = $count;
            }
            elsif ($format_info eq 'GQ') {
                $gq_location = $count;
            }
            $count++;
        }

        #this file doesn't work if there are unknown genotype locations
        unless ($gt_location || $gt_location == 0) {
            die "Format field doesn't have a GT entry, failed to get genotype for $line\n";
        }

        #check to see if line has 0,1,2,etc as genotype numbering, store those in a hash for future reference

        my %alleles_hash;
        foreach my $sample_info (@samples) {                    
            my (@sample_fields) = split(/:/, $sample_info);
            my $genotype = $sample_fields[$gt_location];
            my $allele1 = my $allele2 = ".";
            ($allele1, $allele2) = split(/\//, $genotype);
            if ($allele1 =~ m/\d+/) {
                $alleles_hash{$allele1}++;
                if ($allele2 =~ m/\d+/) {
                    $alleles_hash{$allele2}++;
                }
            }
        }

        my @allele_options = (sort { $a <=> $b } keys %alleles_hash);
        $count = 0;
        foreach my $sample_info (@samples) {
            my (@sample_fields) = split(/:/, $sample_info);
            my $genotype = $sample_fields[$gt_location];
            my $allele1 = my $allele2 = ".";
            my $allele_count;
            ($allele1, $allele2) = split(/\//, $genotype);

            if ($allele1 =~ m/\D+/) {
                $allele_count = '.';
            }
            elsif ($allele1 == $allele2) { #homo
                if ($allele1 == $allele_options[0]) { #homo first variant
                    $allele_count = 0;
                }
                elsif ($allele1 == $allele_options[1]) { #homo second variant
                    $allele_count = 2;
                }
            }
            else { #heterozygous
                $allele_count = 1;
            }

            my $variant_name;
            if ($allele_options[0] == 0) {
                $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt";
            }
            elsif (defined $allele_options[1]) { 
                my ($alt_ref, $alt_alt) = split(/,/, $alt);
                print "1:$alt_ref,2:$alt_alt,3:$alt,4:$allele_options[0],$allele_options[1]\n";
                $variant_name = "$chr"."_"."$pos"."_"."$alt_ref"."_"."$alt_alt";
            }
            else { #for those cases where the line is 100% homo variant
                $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt";
            }
            my $sample_name = $sample_names[$count];
            $variant_hash{$variant_name}++;
            $sample_hash{$sample_name}{$variant_name} = $allele_count;
            $count++;
        }
    }

    #print out header line of variant names
    print "Outputting File of Variant Positions\n";
    foreach my $variant_name (sort keys %variant_hash) {
        if ($self->positions_file) {
            if(defined ($positions_selection_hash{$variant_name})) {
                print $fh "\t$variant_name";
            }
        }
        else {
            print $fh "\t$variant_name";
        }
    }
    print $fh "\n";

    foreach my $sample_name (sort keys %sample_hash) {
        print $fh "$sample_name";
        foreach my $variant_name (sort keys %variant_hash) {
            if ($self->positions_file) {
                if(defined ($positions_selection_hash{$variant_name})) {
                    if (defined $sample_hash{$sample_name}{$variant_name}) {
                        print $fh "\t$sample_hash{$sample_name}{$variant_name}";
                    }
                    else {
                        print $fh "\t.";
                    }
                }
            }
            else {
                if (defined $sample_hash{$sample_name}{$variant_name}) {
                    print $fh "\t$sample_hash{$sample_name}{$variant_name}";
                }
                else {
                    print $fh "\t.";
                }
            }
        }
        print $fh "\n";
   }

   return 1;
}

1;
