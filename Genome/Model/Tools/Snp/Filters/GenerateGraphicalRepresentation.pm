package Genome::Model::Tools::Snp::Filters::GenerateGraphicalRepresentation;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Workflow;
use FileHandle;

class Genome::Model::Tools::Snp::Filters::GenerateGraphicalRepresentation{
    is => 'Command',
    has => [
        c_file =>
        {
            is => 'String',
            doc => 'c4.5 tree output'
        },
        data_format =>
        {
            type => 'String',
            is_optional => 0,
            doc => 'Which Maq::Metrics::Dtr module to use',
            default => 'MaqOSixThree',

        },

        ]
};

sub help_synopsis {
    "Tool version of Dtr3e"
}

sub execute {
    my $self=shift;
    $DB::single=1;

    my $type = $self->data_format;
    my $dtr = eval "Genome::Model::Tools::Maq::Metrics::Dtr::$type->create()";
    unless(defined($dtr)) {
        $self->error_message($@);
        return;
    }
    my @headers = $dtr->headers; #split(/,\s*/,$header_line);
    for (@headers) { s/\-/MINUS/g; s/\+/PLUS/g; s/\s/SPACE/; };
    
    #we could probably take the below method calls and turn them into an execute!!!! OMG
    my $c45_object = Genome::Model::Tools::SeeFourFive::Tree ->create();
    $c45_object->c45_file($self->c_file);
    $c45_object->load_trees;
    my $graph = $c45_object->as_graphviz_obj;
    
    #print the graph to temp
    if($graph) {
        $graph->as_png("/tmp/c4.5graph.png");
    }
    else {
        return;
    }
    
    return 1;
}

sub _demo_c5src {
    return <<EOS

SeeFive.0 [Release 2.05]     Wed Aug  6 18:16:05 2008
-------------------

    Options:
        Application `./testing/first'
        Rule-based classifiers
        Boosted classifiers

Read 870 cases (21 attributes) from ./testing/first.data
Read misclassification costs from ./testing/first.costs

-----  Trial 0:  -----

Rules:

Rule 0/1: (279/24, lift 2.1)
        avg_sum_of_mismatches <= 35
        avg_base_quality > 18
        unique_variant_for_reads_ratio > 0.08
        ->  class G  [0.911]

Rule 0/2: (216/29, lift 2.0)
        pre-27_unique_variant_context_reads_ratio > 0.3333333
        ->  class G  [0.862]

Rule 0/3: (187/5, lift 1.7)
        max_base_quality <= 26
        ->  class WT  [0.968]

Rule 0/4: (220/10, lift 1.7)
        avg_base_quality <= 16
        ->  class WT  [0.950]

Rule 0/5: (98/5, lift 1.7)
        maq_snp_quality <= 23
        ->  class WT  [0.940]

Rule 0/6: (101/25, lift 1.3)
        max_mapping_quality <= 45
        ->  class WT  [0.748]

Rule 0/7: (654/191, lift 1.3)
        pre-27_unique_variant_context_reads_ratio <= 0.3333333
        ->  class WT  [0.707]

Default class: WT

-----  Trial 1:  -----

Rules:

Rule 1/1: (406.9/25.2, lift 1.6)
        maq_snp_quality > 35
        avg_mapping_quality > 31
        max_base_quality > 26
        unique_variant_for_reads_ratio > 0.02222222
        unique_variant_rev_reads_ratio > 0.05263158
        ->  class G  [0.936]



EOS
}

=cut

        my ($chr,$position,$al1,$al2,$qvalue,$al2_read_hg,$avg_map_quality,$max_map_quality,$n_max_map_quality,$avg_sum_of_mismatches,$max_sum_of_mismatches,$n_max_sum_of_mismatches, $base_quality, $max_base_quality, $n_max_base_quality, $avg_windowed_quality, $max_windowed_quality, $n_max_windowed_quality, $for_strand_unique_by_start_site, $rev_strand_unique_by_start_site, $al2_read_unique_dna_context, $for_strand_unique_by_start_site_pre27,$rev_strand_unique_by_start_site_pre27,$al2_read_unique_dna_context_pre27) = split ", ", $line;
        my $al2_read_unique_dna_start = $for_strand_unique_by_start_site + $rev_strand_unique_by_start_site;
        my $al2_read_unique_dna_start_pre27 = $for_strand_unique_by_start_site_pre27 + $rev_strand_unique_by_start_site_pre27;

=cut

1;
