package Genome::Info::CombineVariants;

#REVIEW fdu
#Couldn't find any other module using this under Genome tree.
#Removable unless some other modules/scripts outside of Genome 
#tree use this

use strict;
use warnings;

sub genotype_columns{
    return qw(
    chromosome 
    begin_position
    end_position
    sample_name
    variation_type
    reference
    allele1 
    allele1_type 
    allele1_read_support
    allele1_pcr_product_support
    allele2 
    allele2_type 
    allele2_read_support
    allele2_pcr_product_support
    polyscan_score 
    polyphred_score
    read_type
    con_pos
    filename
    );
}


sub annotated_genotype_columns{
    #TODO remove intensity and detection columns, since these are patient specific
    return qw(
    chromosome 
    begin_position
    end_position
    sample_name
    variation_type
    reference
    allele1 
    allele1_type 
    allele1_read_support
    allele1_pcr_product_support
    allele2 
    allele2_type 
    allele2_read_support
    allele2_pcr_product_support
    polyscan_score 
    polyphred_score
    transcript_name
    transcript_source
    c_position
    trv_type
    priority
    gene_name
    intensity
    detection
    amino_acid_length
    amino_acid_change
    variations 
    );
}

# TODO This is pretty much jacked up because xshi's script seems to be lacking 4 colums and possily be in the wrong order in some cases
sub maf_columns {
    return qw(
    gene_name
    entrez_gene_id
    center
    ncbi_build
    chromosome
    begin_position
    end_position
    strand
    variant_classification
    variation_type
    reference
    tumor_seq_allele1
    tumor_seq_allele2
    dbsnp_rs
    dbsnp_val_status
    tumor_sample_barcode
    matched_norm_sample_barcode
    match_norm_seq_allele1
    match_norm_seq_allele2
    tumor_validation_allele1
    tumor_validation_allele2
    match_norm_validation_allele1
    match_norm_validation_allele2
    verification_status
    mutation_status
    validation_status
    cosmic_comparison
    omim_comparison
    transcript_name
    trv_type
    prot_string
    c_position
    pfam_domain
    ); 
    #  c_position = prot_string_short
    # called_classification = c_position
}

sub maf_header{
    return"Hugo_Symbol\tEntrez_Gene_Id\tCenter\tNCBI_Build\tChromosome\tStart_position\tEnd_position\tStrand\tVariant_Classification\tVariant_Type\tReference_Allele\tTumor_Seq_Allele1\tTumor_Seq_Allele2\tdbSNP_RS\tdbSNP_Val_Status\tTumor_Sample_Barcode\tMatched_Norm_Sample_Barcode\tMatch_Norm_Seq_Allele1\tMatch_Norm_Seq_Allele2\tTumor_Validation_Allele1\tTumor_Validation_Allele2\tMatch_Norm_Validation_Allele1\tMatch_Norm_Validation_Allele2\tVerification_Status\tValidation_Status\tMutation_Status\tCOSMIC_COMPARISON(ALL_TRANSCRIPTS)\tOMIM_COMPARISON(ALL_TRANSCRIPTS)\tTranscript\tCALLED_CLASSIFICATION\tPROT_STRING\tPROT_STRING_SHORT\tPFAM_DOMAIN";
}
    

=pod 

=head1 SUMMARY
This info module contains column formats used in Genome::Model::PolyphredPolyscan, Genome::Model::CombineVariants, and their sub commands

=head2 Genotype columns

=head2 Annotated genotype columns

=head2 Maf columns and header

=head1 METHODS

genotype_columns()

annotated_genotype_columns()

maf_columns()

sub maf_header()

=cut


1;

