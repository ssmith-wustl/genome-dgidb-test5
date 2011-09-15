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

        my $fh = Genome::Sys->open_file_for_writing($output_file);

        my $inFh = IO::File->new( $vcf_file ) || die "can't open file\n";
        my $header_line;
        my @sample_names;
        my %variant_hash;
        my %sample_hash;

        while(my $line = $inFh->getline ) {
                chomp($line);
                if ($line =~ /^\#\#/) {
                        next;
                }
                elsif ($line =~ /^\#CHROM/) {
                        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
                        @sample_names = @samples;
                        print $fh "$project_name";
                        next;
                }

                my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
                my (@format_fields) = split(/:/, $format);
                my $gt_location;
                my $count = 0;
                foreach my $format_info (@format_fields) {
                        if ($format_info eq 'GT') {
                                $gt_location = $count;
                        }
                        else {
                                $count++;
                        }
                }

                unless ($gt_location || $gt_location == 0) {
                        die "Format field doesn't have a GT entry, failed to get genotype for $line\n";
                }

                my %alleles_hash;
                foreach my $sample_info (@samples) {
                        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
                        my (@sample_fields) = split(/:/, $sample_info);
                        my $genotype = $sample_fields[$gt_location];
                        my ($allele1, $allele2) = split(/\//, $genotype);
                        $alleles_hash{$allele1}++;
                        $alleles_hash{$allele2}++;
                }

                my @allele_options = (sort { $a <=> $b } keys %alleles_hash);
                $count = 0;
                foreach my $sample_info (@samples) {
                        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split(/\t/, $line);
                        my (@sample_fields) = split(/:/, $sample_info);
                        my $genotype = $sample_fields[$gt_location];
                        my ($allele1, $allele2) = split(/\//, $genotype);
                        my $allele_count;
                        if ($allele1 == $allele2) { #homo
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
                        else {
                                $variant_name = "$chr"."_"."$pos"."_"."$ref"."_"."$alt";
                        }
                        my $sample_name = $sample_names[$count];
                        $variant_hash{$variant_name}++;
                        $sample_hash{$sample_name}{$variant_name} = $allele_count;
                        $count++;
                }
        }

        foreach my $variant_name (sort keys %variant_hash) {
                print $fh "\t$variant_name";
        }
        print $fh "\n";

        foreach my $sample_name (sort keys %sample_hash) {
                print $fh "$sample_name";
                foreach my $variant_name (sort keys %variant_hash) {
                        if (defined $sample_hash{$sample_name}{$variant_name}) {
                                print $fh "\t$sample_hash{$sample_name}{$variant_name}";
                        }
                        else {
                                print $fh "\t.";
                        }
                }
                print $fh "\n";
       }

       return 1;
}

1;
