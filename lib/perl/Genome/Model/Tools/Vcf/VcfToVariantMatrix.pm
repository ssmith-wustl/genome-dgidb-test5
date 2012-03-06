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
    matrix_genotype_version => {
        is => 'Text',
        is_optional => 1,
        doc => "\"Bases\" or \"Numerical\"",
        default => "Bases",
    },
    transpose=> {
        is => 'Text',
        is_optional => 1,
        doc => "attempt to flip the matrix so that rows  are people, columns are variants, takes more memory",
        default=>0,
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
  
    my $inFh_positions;
    my %positions_selection_hash;
    if ($self->positions_file) {
        $self->load_positions($self->positions_file, \%positions_selection_hash);
    }

    my ($tfh,$temp_path, $inFh);
    if ($self->bed_roi_file) {
        ## Build temp file for vcf limited to roi ##
        ($tfh,$temp_path) = Genome::Sys->create_temp_file;
        unless($tfh) {
            $self->error_message("Unable to create temporary file $!");
            die;
        }
        $temp_path =~ s/\:/\\\:/g;

        print "Loading Position Restriction File\n";

        my $header = $self->grab_header($vcf_file);
        $tfh->print("$header");
        my $intersect_bed_vcf = `intersectBed -a $vcf_file -b $roi_bed`;
        $tfh->print("$intersect_bed_vcf");
        close ($tfh);
        $inFh = Genome::Sys->open_file_for_reading( $temp_path );
    }
    else {
        if(Genome::Sys->_file_type($vcf_file) eq 'gzip') {
            $inFh = Genome::Sys->open_gzip_file_for_reading($vcf_file);
        }
        else {
            $inFh = Genome::Sys->open_file_for_reading($vcf_file);
        }
    }
    print "Loading Genotype Positions from Vcf\n";

    my $fh = IO::File->new($output_file, ">");  # Not using genome sys writing garbage because its a piece of trash
#########prep done begin main vcf parsing loop############

    my @finished_file;
    while(my $line = $inFh->getline ) {
        chomp($line);
        if ($line =~ m/^\#\#/) {
            next;
        }
        elsif ($line =~ /^\#CHROM/) { #grab sample names off of the header line
            my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
            my @sample_names = @samples;
            if($self->transpose) {
                push @finished_file, [$project_name, @sample_names];
            }
            else {
                my $header_line = join ("\t", ($project_name, @sample_names));
                $fh->print("$header_line\n");
            }
            next;
        }
        elsif ($line =~ m/^\#/) { #skip any other commented lines
            next;
        }

        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);

        unless($filter =~ m/PASS/i || $filter eq '.') {
            print "Skipping $chr:$pos:$ref/$alt for having filter status of $filter\n";
            next;
        }
    
        #parse format line to find out where our pattern of interest is in the ::::: system
        my (@format_fields) = split(/:/, $format);
        my $gt_location; #genotype
        my $dp_location; #depth - this is not filled for vasily ucla files - this is currently unused down below
        my $gq_location; #genotype quality - this is only filled in washu vcf for samtools variants, not varscan and not homo ref - this is currrently unused down below
        my $ft_location; #filter
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
            elsif ($format_info eq 'FT') {
                $ft_location = $count;
            }
            $count++;
        }
      
        #this file doesn't work if there are unknown genotype locations
        unless ($gt_location || $gt_location == 0) {
            die "Format field doesn't have a GT entry, failed to get genotype for $line\n";
        }
        unless (defined $ft_location) {
            $ft_location = 'NA';
        }
        my $line;
        if($self->matrix_genotype_version=~ m/numerical/i) {
            $line = $self->format_numeric_output($chr, $pos, $ref, $alt, $gt_location, $ft_location, \@samples);    
        }
        elsif($self->matrix_genotype_version=~ m/bases/i) {
           $line = $self->format_basic_output($chr, $pos, $ref, $alt, $gt_location, $ft_location, \@samples);   
        }
        else {
            die "Please specify a proper matrix_genotype_version of either \"Bases\" or \"Numerical\"";
        }
        if($self->transpose) {
            push @finished_file, $line;
        } else {
            my $out_line = join("\t", @$line);
            $fh->print("$out_line\n");
        }
    }
    if($self->transpose) {
        $self->transpose_and_print($fh, \@finished_file);
    }
    $fh->close;
    return 1;
}

1;

sub load_positions {
    my ($self, $positions_file, $positions_selection_hash) = @_;
    $self->status_message("Loading Position Restriction File");
    my $inFh_positions = Genome::Sys->open_file_for_reading( $positions_file ) || die "can't open $positions_file\n";
    while(my $line = $inFh_positions->getline ) {
        chomp($line);
        my ($chr, $pos, $ref, $alt) = split(/\t/, $line);
        my $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt";
        $positions_selection_hash->{$variant_name}++;
    }
}

sub grab_header {
    my ($self, $vcf_file) = @_;
    if(Genome::Sys->_file_type($vcf_file) eq 'gzip') {
        return `zcat $vcf_file | grep '^#'`;
    }
    else {
        return `grep '^#' $vcf_file`;
    }       
}

sub find_most_frequent_alleles { 
    my ($self, $chr, $pos, $ref, $alt, $gt_location, $ft_location, $sample_ref) = @_;

    my %alleles_hash;
    my @allele_options;
    foreach my $sample_info (@$sample_ref) {                    
        my (@sample_fields) = split(/:/, $sample_info);
        my $genotype = $sample_fields[$gt_location];
        my $allele1 = my $allele2 = ".";
        ($allele1, $allele2) = split(/\//, $genotype);

        my $filter_status;
        if ($ft_location eq 'NA') {
            $filter_status = 'PASS';
        }
        else {
            $filter_status = $sample_fields[$ft_location];
        }

        if ($sample_info eq '.') {
        }
        elsif ($filter_status ne 'PASS' && $filter_status ne '.') {
        }
        elsif ($allele1 =~ m/\d+/) {
            $alleles_hash{$allele1}++;
            if ($allele2 =~ m/\d+/) {
                $alleles_hash{$allele2}++;
            }
        }
    }
    @allele_options = (sort { $a <=> $b } keys %alleles_hash);
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

    return ($variant_name, sort { $a <=> $b } keys %alleles_hash);
}


sub format_numeric_output {
    my ($self, $chr, $pos, $ref, $alt, $gt_location, $ft_location, $sample_ref) = @_;
    my @samples = @$sample_ref;
    my ($variant_name, @allele_options) = $self->find_most_frequent_alleles($chr, $pos, $ref, $alt, $gt_location, $ft_location, $sample_ref);
    my @return_line = ($variant_name);
    for my $sample_info (@samples) {
        my (@sample_fields) = split(/:/, $sample_info);
        my $genotype = $sample_fields[$gt_location];
        my $allele1 = my $allele2 = ".";
        ($allele1, $allele2) = split(/\//, $genotype);

        my $filter_status;
        if ($ft_location eq 'NA') {
            $filter_status = 'PASS';
        }
        else {
            $filter_status = $sample_fields[$ft_location];
        }

        my $allele_count;
        if ($sample_info eq '.') {
            $allele_count = '.';
        }
        elsif ($filter_status ne 'PASS' && $filter_status ne '.') {
            $allele_count = '.';
        }
        elsif ($allele1 =~ m/\D+/) {
            $allele_count = '.';
        }
        elsif ($allele1 == $allele2) { #homo
            my $allele_array_counter = 0;
            foreach my $allele_option (@allele_options) {
                if ($allele1 == $allele_option) { 
                    if ($allele_array_counter == 0) {#homo first variant
                        $allele_count = 0;
                    }
                    else { #homo some other variant -- THIS ISN'T CORRECT WHEN $allele_option is >1! BUT HEY, IT'S SOMETHING AND A BEST GUESS AS TO HOW TO HANDLE THESE MULTIVARIANTS IN THE NUMERICAL FORMAT!
                        $allele_count = 2;
                    }
                }
                $allele_array_counter++;
            }
            unless(defined($allele_count)){
                $allele_count = ".";
                print "Couldn't determine allele count for $variant_name with sample info $sample_info\n";
            }
        }
        else { #heterozygous
            my $allele_array_counter = 0;
            foreach my $allele_option (@allele_options) {
                if ($allele1 == $allele_option) { 
                    if ($allele_array_counter == 0) {#hetero first variant
                        $allele_count = 1;
                    }
                    else { #hetero some other variant combination -- THIS ISN'T CORRECT! BUT HEY, IT'S SOMETHING AND A BEST GUESS AS TO HOW TO HANDLE THESE MULTIVARIANTS IN THE NUMERICAL FORMAT!
                        $allele_count = 1;
                    }
                }
                $allele_array_counter++;
            }
            unless(defined($allele_count)){
                $allele_count = ".";
                print "Couldn't determine allele count for $variant_name with sample info $sample_info\n";
            }
        }
        push @return_line, $allele_count;
    }
    return \@return_line;
}

sub format_basic_output {
    my ($self, $chr, $pos, $ref, $alt, $gt_location, $ft_location, $sample_ref) = @_;
    my @alt_bases = split(/,/, $alt);
    my @allele_option_bases = ($ref, @alt_bases);
    my $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt"; 
    my @return_line = ($variant_name);
    for my $sample_info (@$sample_ref) {
        my (@sample_fields) = split(/:/, $sample_info);
        my $genotype = $sample_fields[$gt_location];
        my ($allele1, $allele2) = split "[/|]", $genotype;

        my $filter_status;
        if ($ft_location eq 'NA') {
            $filter_status = 'PASS';
        }
        else {
            $filter_status = $sample_fields[$ft_location];
        }

        my $allele_type;
        if ($sample_info eq '.') {
            $allele_type = 'NA';
        }
        elsif ($filter_status ne 'PASS' && $filter_status ne '.') {
            $allele_type = 'NA';
        }
        elsif ($allele1 =~ m/^\D+/) { #if allele1 isn't numerical, then it's not vcf spec and must mean a missing value
            $allele_type = 'NA';
        }
        else { #switch numerical genotypes to the ACTG genotypes
            my $a1 = $allele_option_bases[$allele1]; 
            my $a2 = $allele_option_bases[$allele2];
            $allele_type = "$a1/$a2"; #might need to change this to an alpha-sorted genotype for perfection, but it won't affect anything if this isn't sorted
        }
        push @return_line, $allele_type;
    }
    return \@return_line;
}

sub transpose_and_print {
    my ($self, $fh, $aoa_ref) = @_;
    my @transposed;
    for my $row (@$aoa_ref) {
        for my $column (0 .. $#{$row}) {
            push(@{$transposed[$column]}, $row->[$column]);
        }
    }

    for my $new_row (@transposed) {
        my $out_line = join("\t", @$new_row);
        $fh->print("$out_line\n");
    }
}





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

