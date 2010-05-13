package Genome::Model::Tools::TechD::SummarizeCaptureBuilds;

use strict;
use warnings;

use Genome;

my %sort_order = (
    label => 1,
    total_bp => 2,
    total_aligned_bp => 3,
    percent_aligned => 4,
    total_unaligned_bp => 5,
    total_duplicate_bp => 6,
    percent_duplicates => 7,
    paired_end_bp => 8,
    read_1_bp => 9,
    read_2_bp => 10,
    mapped_paired_end_bp => 11,
    proper_paired_end_bp => 12,
    singleton_bp => 13,
    total_target_aligned_bp => 14,
    percent_target_aligned => 15,
    unique_target_aligned_bp => 16,
    duplicate_target_aligned_bp => 17,
    percent_target_duplicates => 18,
    total_off_target_aligned_bp => 19,
    percent_off_target_aligned => 20,
    unique_off_target_aligned_bp => 21,
    duplicate_off_target_aligned_bp => 22,
    percent_off_target_duplicates => 23,
);

class Genome::Model::Tools::TechD::SummarizeCaptureBuilds {
    is => ['Command'],
    has => [
        build_ids => { is => 'Text', doc => 'a comma delimited list of build ids to compare' },
        labels => { is => 'Text', doc => 'a comma delimited list of labels for each build id' },
        alignment_summary => { is => 'Text', doc => 'The output tsv file of consolidated alignment summaries' },
        depth_summary => { is => 'Text', doc => 'The output tsv file of consolidated depth' },
        wingspan => { is_optional => 1, default_value => 0 },
    ],
};



sub execute {
    my $self = shift;

    my @build_ids = split(',',$self->build_ids);
    my @labels = split(',',$self->labels);
    unless (scalar(@build_ids) == scalar(@labels)) {
        die('Un-even number of build_ids and labels!');
    }

    my @alignment_summaries;
    my @as_headers;
    my $headers;
    my $depth_fh = Genome::Utility::FileSystem->open_file_for_writing($self->depth_summary);
    for (my $i = 0; $i < scalar(@build_ids); $i++) {
        my $build_id = $build_ids[$i];
        my $label = $labels[$i];
        my $build = Genome::Model::Build->get($build_id);
        unless ($build) {
            die('Failed to find build for id '. $build_id);
        }
        my $as_hash_ref = $build->alignment_summary_hash_ref();
        $$as_hash_ref{$self->wingspan}{label} = $label;
        push @alignment_summaries, $$as_hash_ref{$self->wingspan};
        unless (@as_headers) {
            @as_headers = sort hash_sort_order (keys %{$$as_hash_ref{$self->wingspan}});
        }
        my $build_depth_line = $label;
        my $header;
        my $stats_hash_ref = $build->coverage_stats_summary_hash_ref();
        for my $min_depth (sort {$b <=> $a} keys %{$stats_hash_ref}) {
            unless ($headers) {
                $header .= "\t". $min_depth .'X';
            }
            my $depth = $$stats_hash_ref{$min_depth}{$self->wingspan}{'Percent Target Space Covered'};
            $build_depth_line .= "\t". $depth;
        }
        unless ($headers) {
            print $depth_fh $header ."\n";
            $headers = 1;
        }
        print $depth_fh $build_depth_line ."\n";
    }
    $depth_fh->close;
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        separator => "\t",
        headers => \@as_headers,
        output => $self->alignment_summary,
    );
    for my $data (@alignment_summaries) {
        $writer->write_one($data);
    }
    $writer->output->close;
    return 1;
}

sub hash_sort_order {
    $sort_order{$a} <=> $sort_order{$b};
}

1;
