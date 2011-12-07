package Genome::Model::Tools::Vcf::Convert::Maf::Vcf2Maf;

#########################################################################
# Vcf2Maf - Converts a VCF file with annotations into a MAF file format #
# 								        #
# AUTHOR: Yanwen You (yyou@genome.wustl.edu)			        #
# 								        #
# CREATED: 6/28/2011 by Yanwen You				        #
# EDITED: 11/11/2011 by William Schierding
#########################################################################

use strict;
use warnings;
use Genome;

# Debugging
# use diagnostics;
# use Data::Dumper;

class Genome::Model::Tools::Vcf::Convert::Maf::Vcf2Maf {
    is => 'Command::V2',
    has_input => [ # All parameters are required
	    vcf_file => {
	        is => 'Text',
	        doc => 'VCF file to convert -- can only be single sample vcf',
            is_optional => 0,
	    },
	    annotation_file => {
	        is => 'Text',
	        doc => 'Annotation file of all positions within the vcf',
            is_optional => 0,
	    },
	    output_file => {
	        is => 'Text',
	        doc => 'Output MAF file',
            is_optional => 0,
	    },
        remove_silent => {
	        is => 'Boolean',
	        doc => 'Remove silent variants from the maf',
            default_value => 0,
	    },
        annotation_has_header => {
	        is => 'Boolean',
	        doc => 'In the pipeline, annotation files dont have a header',
            default_value => 0,
	    },
    ],
    # add has_optional_input here for optional arguments
};

sub help_brief {
    "Convert VCF file with annotation to a MAF file"
}

sub help_synopsis {
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}

# Global variables
our @vcf_columns;
our @annot_columns;
# Standard Maf column names
# BEWARE OF CAPITALIZATION when using these!
our @maf_standard_columns = qw(Hugo_Symbol Entrez_Gene_Id Center NCBI_Build Chromosome Start_Position End_Position Strand Variant_Classification Variant_Type Reference_Allele Tumor_Seq_Allele1 Tumor_Seq_Allele2 dbSNP_RS dbSNP_Val_Status Tumor_Sample_Barcode Matched_Norm_Sample_Barcode Match_Norm_Seq_Allele1 Match_Norm_Seq_Allele2 Tumor_Validation_Allele1 Tumor_Validation_Allele2 Match_Norm_Validation_Allele1 Match_Norm_Validation_Allele2 Verification_Status Validation_Status Mutation_Status Sequencing_Phase Sequence_Source Validation_Method Score BAM_File Sequencer);
our @maf_nonstandard_columns = qw(chromosome_name_WU start_WU stop_WU reference_WU variant_WU type_WU gene_name_WU transcript_name_WU transcript_species_WU transcript_source_WU transcript_version_WU strand_WU transcript_status_WU trv_type_WU c_position_WU amino_acid_change_WU ucsc_cons_WU domain_WU all_domains_WU deletion_substructures_WU transcript_error_WU);
our @maf_columns = (@maf_standard_columns, @maf_nonstandard_columns);

sub execute {
    my $self = shift;

    my $vcf_file = $self->vcf_file;
    my $annotation_file = $self->annotation_file;
    my $output_file = $self->output_file;

    # Verify existence of files
    unless(-e $vcf_file || $annotation_file) {
        $self->error_message("Error: VCF file or annotation does not exist!\n");
        die $self->error_message;
    }
    # Try to open the files
    unless(open VCF, "<$vcf_file") {
        $self->error_message("Error: Could not open file \"$vcf_file\"\n");
        die $self->error_message;
    }
    unless(open ANNOT, "<$annotation_file") {
        $self->error_message("Error: Could not open file \"$annotation_file\"\n");
        die $self->error_message;
    }
    unless(open MAF, ">$output_file") {
        $self->error_message("Error: Could not open file \"$output_file\" for output\n");
        die $self->error_message;
    }

    # Skip the metadata and find the line in VCF with the headers
    my $vcf_line;
    do {
    	$vcf_line = <VCF>;
    } while($vcf_line !~ /^#[^#]/); # match only one hash symbol
    chomp $vcf_line;
    $vcf_line =~ s/^#//; # remove leading '#' symbol
    @vcf_columns = split(/\t/, $vcf_line);

    # Find annotation file headers
    my $annot_line;
    if ($self->annotation_has_header) {
        $annot_line = <ANNOT>; chomp $annot_line;
        @annot_columns = split(/\t/, $annot_line);
    }
    else {
        @annot_columns = qw(chromosome_name start stop reference variant type gene_name transcript_name transcript_species transcript_source transcript_version strand transcript_status trv_type c_position amino_acid_change ucsc_cons domain all_domains deletion_substructures transcript_error);
    }

    # Make the MAF header
    print MAF join("\t", @maf_columns), "\n";

    # Loop through both files line by line to generate the MAF file
    while(1) {
	    $vcf_line = <VCF>;
	    last unless($vcf_line); # stop when EOF is reached
	    $annot_line = <ANNOT>;
	    last unless($annot_line);
	    chomp $vcf_line; chomp $annot_line;

	    # Store vcf fields in a hash
	    my $vcf = $self->make_vcf_hash($vcf_line);
	    # Store annotation fields in hash
	    my $annot = $self->make_annot_hash($annot_line);

	    # convert to maf hash
	    my $maf = $self->make_maf_hash($vcf, $annot);

	    # print it out to the file
	    $self->print_to_maf($maf);
    }

    return 1; # No error
}


################################################################################
# subroutines                                                                  #
################################################################################


#
# Takes a line from a VCF file and puts the fields into a hash
#
# The keys of the hash are the column names (remember, case sensitive)
# and the values of the hash are the value in that column
# In the case that the columns are empty, the values will be the empty string
#
# ex. $self->make_vcf_hash($vcf_line);
#
sub make_vcf_hash {
    my $self = shift;
    my ($vcf_line) = @_;

    my $vcf_hash = {};
    my @vcf = split(/\t/, $vcf_line);
    foreach my $column (@vcf_columns) {
	$vcf_hash->{$column} = shift @vcf;
    }
    return $vcf_hash;
}

#
# Takes a line from a annotation file and puts the fields into a hash
#
# The keys of the hash are the column names (remember, case sensitive)
# and the values of the hash are the value in that column
# In the case that the columns are empty, the values will be the empty string
#
# ex. $self->make_annot_hash($annot_line);
#

sub make_annot_hash {
    my $self = shift;
    my ($annot_line) = @_;

    my $annot_hash = {};
    my @annot = split(/\t/, $annot_line);
    foreach my $column (@annot_columns) {
	$annot_hash->{$column} = shift @annot;
    }
    return $annot_hash;
}

#
# Prints a line to the MAF file, given the maf hash
#
# The columns to be printed are taken from @maf_columns,
# which may or may not include the nonstandard columns.
#
# If a key does not exist in the hash, the value will not be printed
#
# ex. $self->print_to_maf($maf_hash);
#
sub print_to_maf {
    my $self = shift;
    my ($maf) = @_;
    if ($self->remove_silent && $maf->{Variant_Classification} eq 'Silent') {
        next;
    }
    # First one without tab
    print MAF $maf->{$maf_columns[0]};
    foreach my $column (@maf_columns[1 .. $#maf_columns]) {
	print MAF "\t", (defined $maf->{$column} ? $maf->{$column} : "--");
    }
    print MAF "\n";
}

#
# Take the $vcf and $annot hashes and make the $maf hash
#
# Most fields are converted simply by copying over the data to the corresponding column
#
# The conversion isn't perfect
# Some MAF fields are unused, because there is no such
# corresponding data in the VCF and annotation files
#
# If, in the future, such data is found, please implement them
# The unused fields are the commented assignemennt statements
#
# Usage: $self->make_maf_hash($vcf_hash, $annot_hash);
#
sub make_maf_hash {
    my $self = shift;
    my ($vcf, $annot) = @_;
    my $maf = {};

    # if there are two distinct variants at the same location e.g. C,T on corresponding alleles
    if($vcf->{ALT} =~ /,/) {
	<ANNOT>; # throw away a line in the annotation file, because it will have the same info anyways
	@_ = split(/,/, $vcf->{ALT});
	$maf->{Match_Norm_Seq_Allele1} = $_[0];
	$maf->{Match_Norm_Seq_Allele2} = $_[1];
    } else {
	@_ = split(/:/, $vcf->{$vcf_columns[-1]}); # split 0/1:.:27:38:1:12:0.4444:42.95
	my @genotype = split(/\//, $_[0]); # get the genotype e.g. "0/1" and split it
   	$maf->{Match_Norm_Seq_Allele1} = $genotype[0] ? $vcf->{ALT} : $vcf->{REF};
	$maf->{Match_Norm_Seq_Allele2} = $genotype[1] ? $vcf->{ALT} : $vcf->{REF};
    }

    # Check for consistency in chromosome number
    if ($vcf->{CHROM} eq $annot->{chromosome_name}) {
	$maf->{Chromosome} = $vcf->{CHROM};
    } else {
	# this should not happen, so die
	die "VCF and Annotation files have different chromosome numbers!\n",
	    "VCF: Chromosome $vcf->{CHROM}, Position $vcf->{POS}\n",
	    "Annotation: Chromosome $annot->{chromosome_name}, Position $annot->{start}";
	# Alternatively: don't die, and try to skip the inconsistent lines
	# Replace the die statement above with the following to implement this
	#
	# warn "VCF and Annotation files have different chromosome numbers!\n",
	#      "VCF: Chromosome $vcf->{CHROM}, Position $vcf->{POS}\n",
	#      "Annotation: Chromosome $annot->{chromosome_name}, Position $annot->{start}";
	# # if vcf is ahead of the annotation
	# if($vcf->{CHROM} ge $annot->{chromosome_name}) {
	#     # skip a line in the annotation file to catch up
	#     <ANNOT>;
	#     next;
	# } else { # annotation is ahead of the vcf
	#     # skip a line in the vcf file to catch up
	#     <VCF>;
	#     next;
	# }
    }

    # Check for consistency in chromosome position
    if ($vcf->{POS} == $annot->{start}) {
    	$maf->{Start_Position} = $vcf->{POS};
    } else {
	    #die "VCF and Annotation files have different position numbers!\n","VCF: Chromosome $vcf->{CHROM}, Position $vcf->{POS}\n","Annotation: Chromosome $annot->{chromosome_name}, Position $annot->{start}\n";
	    #Don't die, and try to skip the inconsistent lines
        warn "VCF and Annotation files have different position numbers!\n",
          "VCF: Chromosome $vcf->{CHROM}, Position $vcf->{POS}\n",
          "Annotation: Chromosome $annot->{chromosome_name}, Position $annot->{start}";
        # if vcf is ahead of annotation
        if($vcf->{POS} ge $annot->{start}) {
            # skip a line in the annotation file to catch up
            <ANNOT>;
            next;
        } else { # annotation is ahead of vcf
            # skip a line in the vcf file to catch up
            <VCF>;
            next;
        }
    }

    $maf->{Hugo_Symbol} = $annot->{gene_name};

#taken from gmt annotate revise-maf
    my $entrez_gene_ids;
    my $Hugo_Symbol = $maf->{Hugo_Symbol};
    my @gene_info = GSC::Gene->get(gene_name => $Hugo_Symbol);
    if (@gene_info) {
		for my $info (@gene_info) {
		    my $locus_link_id = $info->locus_link_id;
		    if ($locus_link_id) {
			    my $id = $entrez_gene_ids->{$Hugo_Symbol};
			    if ($id) {
			        unless ($id =~ /$locus_link_id/) {
        				$entrez_gene_ids->{$Hugo_Symbol}="$id:$locus_link_id";
			        }
			    } else {
			        $entrez_gene_ids->{$Hugo_Symbol}=$locus_link_id;
			    }
		    }
		}
        $maf->{Entrez_Gene_Id} = $entrez_gene_ids->{$Hugo_Symbol};
    }
    else {
        $maf->{Entrez_Gene_Id} = "-";
    }


    $maf->{Center} = 'genome.wustl.edu';
    $maf->{NCBI_Build} = 'NCBI-human-build36';
    $maf->{End_Position} = $annot->{stop};
    $maf->{Strand} = 0; # Unsure whether this is OK? Just assumed 0 for all inputs

    $maf->{Variant_Classification} = &trv_to_mutation_type($annot->{trv_type});

    warn "Unrecognized trv_type \"$annot->{trv_type}\" in annotation file: $maf->{Hugo_Symbol}, chr$maf->{Chromosome}:$maf->{Start_Position}-$maf->{End_Position}\n" if ! $maf->{Variant_Classification};

    $maf->{Variant_Type} = $annot->{type}; # SNP, INS, DEL, etc.
    $maf->{Reference_Allele} = $vcf->{REF};

    # Temporary additions to make the SMG test work for MRSA data
    $maf->{Tumor_Seq_Allele1} = $maf->{Match_Norm_Seq_Allele1};
    $maf->{Tumor_Seq_Allele2} = $maf->{Match_Norm_Seq_Allele2};

    $maf->{dbSNP_RS} = "-";
    $maf->{dbSNP_Val_Status} = "-";

	# required to match correctly
    $maf->{Tumor_Sample_Barcode} = $vcf_columns[-1];
    $maf->{Matched_Norm_Sample_Barcode} = $vcf_columns[-1]; # Ex. H_MRS-6201-1025127

    $maf->{Tumor_Validation_Allele1} = "-";
    $maf->{Tumor_Validation_Allele} = "-";
    $maf->{Match_Norm_Validation_Allele1} = "-";
    $maf->{Match_Norm_Validation_Allele2} = "-";
    $maf->{Verification_Status} = $vcf->{FILTER} eq "PASS" ? "Strandfilter_Passed" : "-";
    $maf->{Validation_Status} = "Unknown";
    $maf->{Mutation_Status} = "Germline";
    $maf->{Validation_Method} = "4";
    $maf->{Sequencing_Phase} = "Capture";
    $maf->{Sequence_Source} = "-";
    $maf->{Score} = "-";
    $maf->{BAM_File} = "-";
    $maf->{Sequencer} = "GaIIx or HiSeq";


    # Below are non standard MAF columns
    # change the our declaration of @maf_colums at the top of the file to include/exclude printing these to file
    $maf->{chromosome_name_WU} = $maf->{Chromosome};
    $maf->{start_WU} = $maf->{Start_Position};
    $maf->{stop_WU} = $maf->{End_Position};
    $maf->{reference_WU} = $maf->{Reference_Allele};
    $maf->{variant_WU} = $vcf->{ALT};
    $maf->{type_WU} = $maf->{Variant_Type};
    $maf->{gene_name_WU} = $maf->{Hugo_Symbol};
    $maf->{transcript_name_WU} = $annot->{transcript_name};
    $maf->{transcript_species_WU} = $annot->{transcript_species};
    $maf->{transcript_source_WU} = $annot->{transcript_source};
    $maf->{transcript_version_WU} = $annot->{transcript_version};
    $maf->{strand_WU} = $annot->{strand};
    $maf->{transcript_status_WU} = $annot->{transcript_status};
    $maf->{trv_type_WU} = $annot->{trv_type};
    $maf->{c_position_WU} = $annot->{c_position};
    $maf->{amino_acid_change_WU} = $annot->{amino_acid_change};
    $maf->{ucsc_cons_WU} = $annot->{ucsc_cons};
    $maf->{domain_WU} = $annot->{domain};
    $maf->{all_domains_WU} = $annot->{all_domains};
    $maf->{deletion_substructures_WU} = $annot->{deletion_substructures};
    $maf->{transcript_error_WU} = $annot->{transcript_error};
    return $maf;
}
# Translate from annotation to maf. Somre are left blank and untranslated. Do they even exist in MAF?
#############################################################
# trv_to_mutation_type - Converts WU var types to MAF variant classifications
#
#############################################################
sub trv_to_mutation_type {
    my $trv_type = shift;
  
    return( "Missense_Mutation" ) if( $trv_type eq "missense" );
    return( "Nonsense_Mutation" ) if( $trv_type eq "nonsense" || $trv_type eq "nonstop" );
    return( "Silent" ) if( $trv_type eq "silent" );
    return( "Splice_Site" ) if( $trv_type eq "splice_site" || $trv_type eq "splice_site_del" || $trv_type eq "splice_site_ins" );
    return( "Frame_Shift_Del" ) if( $trv_type eq "frame_shift_del" );
    return( "Frame_Shift_Ins" ) if( $trv_type eq "frame_shift_ins" );
    return( "In_Frame_Del" ) if( $trv_type eq "in_frame_del" );
    return( "In_Frame_Ins" ) if( $trv_type eq "in_frame_ins" );
    return( "RNA" ) if( $trv_type eq "rna" );
    return( "3'UTR" ) if( $trv_type eq "3_prime_untranslated_region" );
    return( "5'UTR" ) if( $trv_type eq "5_prime_untranslated_region" );
    return( "3'Flank" ) if( $trv_type eq "3_prime_flanking_region" );
    return( "5'Flank" ) if( $trv_type eq "5_prime_flanking_region" );
  
    return( "Intron" ) if( $trv_type eq "intronic" || $trv_type eq "splice_region" || $trv_type eq "splice_region_ins" || $trv_type eq "splice_region_del");
    return( "Targeted_Region" ) if( $trv_type eq "-" );
  
    return( "" );
}

1;
