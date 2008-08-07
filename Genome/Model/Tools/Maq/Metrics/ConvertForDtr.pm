package Genome::Model::Tools::Maq::Metrics::ConvertForDtr;

use strict;
use warnings;

use above "Genome";
use Command;
use IO::File;
use List::Util 'shuffle';

class Genome::Model::Tools::Maq::Metrics::ConvertForDtr {
    is => 'Command',
    has => [
        input => 
        { 
            type => 'String',
            is_optional => 0,
            doc => "input file ofs with
            lots of data about them in columns",
        },
        output => {
            is => 'FileName',
            doc => 'results...',
        },
   ]
};

sub help_detail {
    "This module is intended to be a front end for running C4.5 to generate decision trees"
}

sub execute {
    my $self=shift;
    unless(-f $self->input) {
        $self->error_message("Good snps file is not a file: " . $self->input);
        return;
    }
    my $expr_fh=IO::File->new($self->input);
    unless($expr_fh) {
        $self->error_message("Failed to open filehandles for: " .  $self->input);
        return;
    }

    my $input_headers = $expr_fh->getline;

    my @data = @{$self->make_data_array($expr_fh)};
    my $output = $self->output;
    my $fh = IO::File->new(">$output");
    unless ($fh) {
        $self->error_message("failed to open $output: $!");
        return;
    }
    $fh->print(map { $_, "\n" } $self->headers);
    $fh->print(map { $_, "\n" } @data);

    return 1;
}

sub make_data_array {
    my ($self, $handle) = @_;

    #useful array function
    #@shuffled = shuffle(@list);

    my @data;
    while(my $line = $handle->getline) {
        chomp $line;
        my ($chr,
            $position,
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

        if ($total_depth == 0) {
            die "Found total depth of zero on line in input:\n\n$line\n\n";
        }

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
        );
        push @data, join (",",@attributes);
    }
    return (\@data,);
}

sub headers {
   my @names = (   "variant allele",
        "reference allele",
        "maq_snp_quality",
        "avg_mapping_quality",
        "max_mapping_quality",
        "fraction_reads_with_max_mapping_quality",
        "avg_sum_of_mismatches",
        "max_sum_of_mismatches",
        "fraction_reads_with_max_sum",
        "avg_base_quality",
        "max_base_quality",
        "fraction_reads_with_max_base_quality",
        "avg_windowed_quality",
        "max_windowed_quality",
        "fraction_reads_with_max_windowed_quality",
        "unique_variant_for_reads_ratio",
        "unique_variant_rev_reads_ratio",
        "unique_variant_context_reads_ratio",
        "pre-27_unique_variant_for_reads_ratio",
        "pre-27_unique_variant_rev_reads_ratio",
        "pre-27_unique_variant_context_reads_ratio",
        "maq_avg_num_of_hits",
        "maq_strong_weak_qual_difference",
    );
  return \@names;
}



####PSEUDOCODE#####
#INPUT: LIST OF GOOD SNPS with experimental appended
#INPUT: LIST OF BAD SNPS with experimental appended



####FIRST THING TO DO
####MODIFY COLUMNS TO MAKE ANY RELATED COLUMNS INDEPENDENT
####APPEND STATUS OF ,G to GOOD SNPS file. 
### APPEND STATUS OF ,WT TO BAD SNPS file.

##LIST ALTERATION/PROCESSING DONE

###CONCATENATE LISTS INTO NEW FILE

##GENERATE ANCILLARY CONFIG FILES FOR C4.5
##.NAMES - names of columns and how they vary. "continous"  "discrete: good, bad"
##.DATA - training set
##.TEST - test set
