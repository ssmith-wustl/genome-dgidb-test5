package Genome::Model::Tools::Maq::Metrics::Dtr;

use strict;
use warnings;
use Genome;            
use IO::File;
class Genome::Model::Tools::Maq::Metrics::Dtr {
    is => 'Command',
    has => [ 
    names => {},
    decision => {},
    debug_mode => {default=>0},
    ],
};

#This module is to handle formatting and headers for Decision tree training and running

sub create {
    $DB::single = 1;
    my $class = shift;
    #Overriding create so we can set headers and type outside of the class declaration
    #Cause that would look fugly
    my $self = $class->SUPER::create(@_);
    return unless $self;

    #initialize constant class variables here!
    my @names = (   "variant_base: A,C,G,T",
        "reference_base: A,C,G,T",
        "maq_snp_quality: continuous",
        "avg_mapping_quality: continuous",
        "max_mapping_quality: continuous",
        "fraction_reads_with_max_mapping_quality: continuous",
        "avg_sum_of_mismatches: continuous",
        "max_sum_of_mismatches: continuous",
        "fraction_reads_with_max_sum: continuous",
        "avg_base_quality: continuous",
        "max_base_quality: continuous",
        "fraction_reads_with_max_base_quality: continuous",
        "avg_windowed_quality: continuous",
        "max_windowed_quality: continuous",
        "fraction_reads_with_max_windowed_quality: continuous",
        "unique_variant_for_reads_ratio: continuous",
        "unique_variant_rev_reads_ratio: continuous",
        "unique_variant_context_reads_ratio: continuous",
        "pre27_unique_variant_for_reads_ratio: continuous",
        "pre27_unique_variant_rev_reads_ratio: continuous",
        "pre27_unique_variant_context_reads_ratio: continuous",
        "maq_avg_num_of_hits: continuous",
        "maq_strong_weak_qual_difference: continuous",
        "total_depth: continuous",
    );
    $self->names(\@names);
    
    #Define the decision
    $self->decision(["G","WT"]);
    return $self;
}

sub names_file_string {
    my ($self) = @_;
    #for now just assume that people have provided a valid filehandle
    my $string = join ",", @{$self->decision};
    $string .= ".\n";
    $string .= join "\n", @{$self->names};
    return $string;
}


sub headers {
    my $self = shift;
    my @headers;
    foreach my $attribute (@{$self->names}) {
        if($attribute =~ /^(.+)\:/) {
            push @headers,$1;
        }
        else {
            $self->error_message("Invalid header");
            return;
        }
    }
    return @headers;
}

sub make_attribute_array {
    my ($self,$line) = @_;
    #This is also a candidate for some OO goodness, Module for reading metrics files
    #The line should be pre-chomped, but we will do so just to make sure
    chomp $line;
    my ($chr,
        $pos,
        $al1,
        $al2,
        $qvalue,
        $al2_read_hg,
        $avg_map_quality,
        $max_map_quality,
        $n_max_map_quality,
        $avg_sum_of_mismatches,
        $max_sum_of_mismatches,
        $n_max_sum_of_mismatches,
        $base_quality,
        $max_base_quality,
        $n_max_base_quality,
        $avg_windowed_quality,
        $max_windowed_quality,
        $n_max_windowed_quality,
        $for_strand_unique_by_start_site,
        $rev_strand_unique_by_start_site,
        $al2_read_unique_dna_context,
        $for_strand_unique_by_start_site_pre27,
        $rev_strand_unique_by_start_site_pre27,
        $al2_read_unique_dna_context_pre27,
        $ref_read_hg,
        $ref_avg_map_quality,
        $ref_max_map_quality,
        $ref_n_max_map_quality,
        $ref_avg_sum_of_mismatches,
        $ref_max_sum_of_mismatches,
        $ref_n_max_sum_of_mismatches,
        $ref_base_quality,
        $ref_max_base_quality,
        $ref_n_max_base_quality,
        $ref_avg_windowed_quality,
        $ref_max_windowed_quality,
        $ref_n_max_windowed_quality,
        $ref_for_strand_unique_by_start_site,
        $ref_rev_strand_unique_by_start_site,
        $ref_read_unique_dna_context,
        $ref_for_strand_unique_by_start_site_pre27,
        $ref_rev_strand_unique_by_start_site_pre27,
        $ref_read_unique_dna_context_pre27,
        $total_depth,
        $cns2_depth,
        $cns2_avg_num_reads,
        $cns2_max_map_quality,
        $cns2_allele_qual_diff,
    ) = split ",", $line;
    #create dependent variable ratios
    #everything is dependent on # of reads so make a ratio
    return if $total_depth == 0;
    my @attributes = ($al2,
        $al1,
        $qvalue,
        $avg_map_quality,
        $max_map_quality,
        $n_max_map_quality/$total_depth,
        $avg_sum_of_mismatches,
        $max_sum_of_mismatches,
        $n_max_sum_of_mismatches/$total_depth,
        $base_quality,
        $max_base_quality,
        $n_max_base_quality/$total_depth,
        $avg_windowed_quality,
        $max_windowed_quality,
        $n_max_windowed_quality/$total_depth,
        $for_strand_unique_by_start_site/$total_depth,
        $rev_strand_unique_by_start_site/$total_depth,
        $al2_read_unique_dna_context/$total_depth,
        $for_strand_unique_by_start_site_pre27/$total_depth,
        $rev_strand_unique_by_start_site_pre27/$total_depth,
        $al2_read_unique_dna_context_pre27/$total_depth,
        $cns2_avg_num_reads,
        $cns2_allele_qual_diff,
        $total_depth,
    );
    return @attributes;
    
}

1;

