package Genome::Model::Tools::TechD::SummarizeCaptureBuilds;

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
    my $headers;
    my $depth_fh = Genome::Utility::FileSystem->open_file_for_writing($self->depth_summary);
    for (my $i = 0; $i < scalar(@build_ids); $i++) {
        my $build_id = $build_ids[$i];
        my $label = $labels[$i];
        my $build = Genome::Model::Build->get($build_id);
        unless ($build) {
            die('Failed to find build for id '. $build_id);
        }
        push @alignment_summaries, $build->alignment_summary_file($self->wingspan);
        my $build_depth_line = $label;
        my $header;
        my $stats_hash_ref = $build->coverage_stats_summary_hash_ref();
        for my $min_depth (sort {$a <=> $b} keys %{$stats_hash_ref}) {
            unless ($headers) {
                $header .= "\t". $min_depth;
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
    unless (Genome::Model::Tools::BioSamtools::CompareAlignmentSummaries->execute(
        input_files => \@alignment_summaries,
        output_file => $self->alignment_summary,
        labels => \@labels,
    )) {
        die('Failed to generate alignment summary comparison '. $self->alignment_summary);
    }
    return 1;
}
