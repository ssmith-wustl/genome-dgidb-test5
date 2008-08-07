package Genome::Model::Tools::Snp::C45;

use strict;
use warnings;

use above "Genome";
use Command;
use IO::File;
use List::Util 'shuffle';

class Genome::Model::Tools::Snp::C45 {
    is => 'Command',
    has => [
    good_snps_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "input file of known real snps with
        lots of data about them in columns",
    },
    bad_snps_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "input file of known false snps with
        lots of data about them in columns",
    },
    name_file =>
    {
        type => 'String',
        is_optional => 1,
        doc => "config file detailing name and range 
        of columns in the two snp files for C4.5",
    },
    training_set_size =>
    {
        type => 'Integer',
        is_optional => 1,
        doc => "Size of training set. default=200.
        Specify 'all' to use entire input.",
        default => '200'
    },        
    data_file =>
    {
        type => 'String',
        is_optional => 1,
        doc => "file of data which C4.5 will use to 
        attempt to construct good rules. If not specified
        a default subset will be created at runtime",
    },
    test_file =>
    {  
        type => 'String',
        is_optional =>1,
        doc => "file of data which C4.5 will use to
        test out the rules it decides on. if not specified,
        good/bad concat will be used",
    }       
    ]
};


sub execute {
    my $self=shift;
    unless(-f $self->good_snps_file) {
        $self->error_message("Good snps file is not a file: " . $self->good_snps_file);
        return;
    }
    unless(-f $self->bad_snps_file) {
        $self->error_message("bad snps file is not a file: " . $self->bad_snps_file);
        return;
    }
    #unless(-f $self->name_file) {
    #    $self->error_message("bad snps file is not a file: " . $self->name_file);
    #     return;
    #}
    #unless($self->test_file && -f $self->test_file) {
    #   $self->error_message("bad snps file is not a file: " . $self->test_file);
    #return;
    #}
    # unless($self->data_file && -f $self->data_file) {
    #    $self->error_message("bad snps file is not a file: " . $self->data_file);
    # return;
    # }
    my $good_fh=IO::File->new($self->good_snps_file);
    my $bad_fh=IO::File->new($self->bad_snps_file);
    unless($bad_fh && $good_fh) {
        $self->error_message("Failed to open filehandles for: " .  $self->good_snps_file . " and/or " . $self->bad_snps_file);
        return;
    }


    #lots of processing goes here... to both bad and good files
    #independify various columsn, add WT/G to end of each line
    #they should probably be written either to two new files or just dumped right into test and data files. 

    my ($decision, $names) = $self->make_names_array();

    my @data = @{$self->make_data_array($good_fh,"G")};
    push @data, @{$self->make_data_array($bad_fh,"WT")};

    my $data_file_handle;
    my $test_file_handle;
    my $name_file_handle;
    #if we didn't specify a data file. probably the normal case.
    unless($self->data_file) {
        $self->data_file("/tmp/C45.data");
        $data_file_handle=IO::File->new(">" . $self->data_file);
        ###use some procedure to fill this with a random subset of shit(stuff).
    } 
    unless($self->test_file) {
        $self->test_file("/tmp/C45.test");
        $test_file_handle=IO::File->new(">" . $self->test_file);
        #concatenate both files and shove them in here.
    } 
    $self->name_file("/tmp/C45.names");
    $name_file_handle=IO::File->new(">" . $self->name_file);
    ###use some procedure to fill this with a random subset of shit(stuff)

    @data = shuffle @data;

#write the names file
    print $name_file_handle join "\n", $decision.".\n",@$names;


#Use splice to hack apart the array into a test set and a training set.
#Then join together with commas etc
#The following line does both together
    my @data_lines;
    unless($self->training_set_size eq 'all') {
        @data_lines = map {join ", ", @$_} splice(@data,0,$self->training_set_size);
    }

    print $data_file_handle join "\n", @data_lines;
    print $data_file_handle "\n";

    unless($self->training_set_size eq 'all') { 
        my @test_lines = map {join ", ", @$_} @data;
        print $test_file_handle join "\n", @test_lines;
        print $test_file_handle "\n";
    }

    ###Run C4.5 here



}
1;

sub help_detail {
    "This module is intended to be a front end for running C4.5 to generate decision trees"
}
sub make_names_array {
    my ($self) = @_;
    my $decision = "G,WT";
    my @names = (   "variant allele: A,C,G,T",
        "reference allele: A,C,G,T",
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
        "pre-27_unique_variant_for_reads_ratio: continuous",
        "pre-27_unique_variant_rev_reads_ratio: continuous",
        "pre-27_unique_variant_context_reads_ratio: continuous",
        "maq_avg_num_of_hits: continuous",
        "maq_strong_weak_qual_difference: continuous",
    );
    return ($decision,\@names);
}

sub make_data_array {
    my ($self, $handle, $status) = @_;

    #useful array function
    #@shuffled = shuffle(@list);

    my @data;
    while(my $line = $handle->getline) {
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
            $status,
        );
        push @data, \@attributes;
    }
    return (\@data,);
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
