package Genome::Model::ReferenceAlignment::Command::CaptureQc;
use strict;
use warnings;
use Cwd;

class Genome::Model::ReferenceAlignment::Command::CaptureQc {
    is => 'Genome::Command::Base',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'use these models and their samples for QC',
            shell_args_position => 1,
        },
    ],
    has_optional => [
        qc_directory => {
            is => 'Text',
            default => cwd(),
            doc => 'path to gmt capture germline-model-group-qc output',
        },
        output_directory => {
            is => 'Text',
            default => cwd(),
            doc => 'Dir to store sample/index/pool summaries',
        },
        debug => {
            is => 'Boolean',
            default => 0,
            doc => 'Print debug messages that could help fix oddities',
        },
    ],
    doc => 'Summarize information on models from germline-model-group and germline-model-group-qc',
};

sub help_brief { 'Summarize information on models from germline-model-group and germline-model-group-qc' }

sub help_detail{ help_brief() . "\nExample: genome model reference-alignment capture-qc 10407 -qc_dir ./germline-model-group-qc_output" }

sub execute {
    my $self = shift;
    print "Gathering data\n" if $self->debug;
    my @instrument_data = map{$_->instrument_data}$self->models;
    my @qc_models = Genome::Model::ReferenceAlignment->default_lane_qc_model_for_instrument_data(@instrument_data);
    my $missing_qc_models = (@instrument_data - @qc_models);
    if ($missing_qc_models) {
        warn "Missing $missing_qc_models lane qc model(s).\n";
    }
    my (%build_to_metrics, %index_to_builds, %pool_to_builds);
    for my $model ($qc_models) {
        my $build = $model->last_succeeded_build || next;
        print 'Gathering data for build: ' . $build->id . "\n" if $self->debug;

        #Non qc data
        my ($align_stats, $cov_stats);
        eval{
            my $cov_result = $build->coverage_stats_result;
            $align_stats = $cov_result->alignment_summary_hash_ref->{0};
            $cov_stats = $cov_result->coverage_stats_summary_hash_ref->{0};
        };
        if( $@ ){
            $align_stats = $build->alignment_summary_hash_ref->{0};
            $cov_stats = $build->coverage_stats_summary_hash_ref->{0};
        }
        $build_to_metrics{$build->id} = $self->get_metrics_for_non_qc_data(
            $align_stats,
            $cov_stats,
            $build->merged_alignment_result->merged_alignment_bam_flagstat
        );

        #qc data
        $build_to_metrics{$build->id} = {%{$self->get_metrics_for_qc_data($build)},%{$build_to_metrics{$build->id}}};


        #Find all the models for each index and pool
        #Take the first instrument_data's index until a decision is made
        #  on how to handle per-sample data, when per-instrument-data data is unavailable
        #  although this won't matter once we start using QC models only
        my $index = (map{$_->index_sequence}$model->instrument_data)[0];
        my $pool = Genome::Model::Command::Services::AssignQueuedInstrumentData->_resolve_pooled_sample_name_for_instrument_data((),$model->instrument_data);

        #Build reference of each index and pool to all of their builds to summarize data per each of these
        push @{$index_to_builds{$index}}, $build;
        push @{$pool_to_builds{$pool}}, $build;
    }

    print "Summarizing data\n" if $self->debug;
    my $dir = $self->output_directory;
    print "Writing subject_summary\n" if $self->debug;
    $self->write_full_summary(
        Genome::Sys->open_file_for_overwriting($dir . "/subject_summary.tsv"),
        \%build_to_metrics,
    );
    print "Writing index_summary\n" if $self->debug;
    $self->write_averaged_summary(
        Genome::Sys->open_file_for_overwriting($dir . "/index_summary.tsv"),
        \%index_to_builds,
        \%build_to_metrics,
    );
    print "Writing pool_summary\n" if $self->debug;
    $self->write_averaged_summary(
        Genome::Sys->open_file_for_overwriting($dir . "/pool_summary.tsv"),
        \%pool_to_builds,
        \%build_to_metrics,
    );
    return 1;
}

sub common_headers {
    (
        '%40Depth',
        '%30Depth',
        '%20Depth',
        '%15Depth',
        '%10Depth',
        '%Dup',    # percent duplication
        '%Mapped',
        '%UniqOn', # % of Unique On Target Reads
        '%UniqOff',# % of Unique Off Target Reads
        '%TotalOn',
        '%TotalOff',
        '%Unaligned',
        'SNPsCalled',
        'WithGenotype',
        'MetMinDepth',
        'Reference',
        'RefMatch',
        'RefWasHet',
        'RefWasHom',
        'Variant',
        'VarMatch',
        'HomWasHet',
        'HetWasHom',
        'VarMismatch',
        'VarConcordance',
        'RareHomConcordance',
        'OverallConcordance',
    )
}

sub metric_names {
    qw(
    wingspan_0_40_coverage_depth
    wingspan_0_30_coverage_depth
    wingspan_0_20_coverage_depth
    wingspan_0_15_coverage_depth
    wingspan_0_10_coverage_depth
    wingspan_0_percent_duplication
    wingspan_0_percent_mapped
    wingspan_0_percent_unique_on_target
    wingspan_0_percent_unique_off_target
    wingspan_0_percent_total_on_target
    wingspan_0_percent_total_off_target
    wingspan_0_percent_unaligned
    snps_called
    with_genotype
    met_min_depth
    reference
    ref_match
    ref_was_het
    ref_was_hom
    variant
    var_match
    hom_was_het
    het_was_hom
    var_mismatch
    var_concordance
    rare_hom_concordance
    overall_concordance
    )
}

sub write_subject_headers {
    my $self = shift;
    my $fh = shift || die;
    print $fh join ("\t", (
            'Model',
            'Build',
            'Sample',
            'Libraries',
            'Index',
            'Pooled library',
            $self->common_headers,
        )) . "\n";
}

sub write_index_headers {
    my $self = shift;
    my $fh = shift || die;
    print $fh join ("\t", (
            'Index',
            $self->common_headers,
        )) . "\n";
}

sub write_pool_headers {
    my $self = shift;
    my $fh = shift || die;
    print $fh join ("\t", (
            'Pool',
            $self->common_headers,
        )) . "\n";
}

sub write_averaged_summary {
    #Accepts builds grouped by a value, and averages all build metrics in each grouping
    my $self = shift;
    my $fh = shift || die;
    my $grouping_value_to_builds = shift || die;
    my $build_to_metrics = shift || die;
    $self->write_index_headers($fh);

    while (my ($grouping_value,$builds) = each %$grouping_value_to_builds) {
        my %sum_value;
        for my $build (@$builds) {
            for my $metric_name ($self->metric_names) {
                $sum_value{$metric_name} += $build_to_metrics->{$build->id}{$metric_name} || 0;
            }
        }
        print $fh join("\t",
            $grouping_value,
            map{
            print "Metric for $_ : " . $sum_value{$_} / @$builds . "\n";
            return sprintf ("%.2f%%", $sum_value{$_} / @$builds) if /percentage/;
            sprintf ("%.2f", $sum_value{$_} / @$builds);
            }$self->metric_names
        ) . "\n";
    }
}

sub write_full_summary {
    my $self = shift;
    my $fh = shift || die;
    my $build_to_metrics = shift || die;
    $self->write_subject_headers($fh);

    for my $model ($self->models){
        next if $model->subject->name =~ /Pooled_Library/;
        my $build = $model->last_succeeded_build || next;

        #Take the first instrument_data's index until a decision is made
        #  on how to handle per-sample data, when per-instrument-data data is unavailable
        my $index = (map{$_->index_sequence}$model->instrument_data)[0];
        my $pool = Genome::Model::Command::Services::AssignQueuedInstrumentData->_resolve_pooled_sample_name_for_instrument_data((),$model->instrument_data);
        my $libraries = $build->instrument_data->library->name;

        #add model->instrument_data->lane

        print $fh join("\t",
            $model->id,
            $build->id,
            $model->subject->name,
            $libraries,
            $index,
            $pool,
            map{
            print "Metric for $_ : " . $build_to_metrics->{$build->id}{$_} . "\n";
            return sprintf ("%.2f%%", $build_to_metrics->{$build->id}{$_}) if /percentage/;
            sprintf ("%.2f", $build_to_metrics->{$build->id}{$_});
            }$self->metric_names
        ) . "\n";
    }
}

sub get_metrics_for_non_qc_data {
    my $self = shift;
    my $align_stats = shift;
    my $cov_stats = shift;
    my $flagstat = shift;

    my %metric_to_value;

    my $unique_on_target = $align_stats->{unique_target_aligned_bp};
    my $duplicate_on_target = $align_stats->{duplicate_target_aligned_bp};
    my $unique_off_target = $align_stats->{unique_off_target_aligned_bp};
    my $duplicate_off_target = $align_stats->{duplicate_off_target_aligned_bp};
    my $unaligned = $align_stats->{total_unaligned_bp};

    my $total = $unique_on_target+$duplicate_on_target+$unique_off_target+$duplicate_off_target+$unaligned;
    my $percent_unique_on_target = $unique_on_target/$total*100;
    my $percent_duplicate_on_target = $duplicate_on_target/$total*100;
    my $percent_unique_off_target = $unique_off_target/$total*100;
    my $percent_duplicate_off_target = $duplicate_off_target/$total*100;

    $metric_to_value{wingspan_0_percent_total_on_target} = $percent_duplicate_on_target + $percent_unique_on_target;
    $metric_to_value{wingspan_0_percent_total_off_target} = $percent_duplicate_off_target + $percent_unique_off_target;
    $metric_to_value{wingspan_0_percent_unaligned} = $unaligned/$total*100;

    $metric_to_value{wingspan_0_percent_unique_on_target} = $percent_unique_on_target;
    $metric_to_value{wingspan_0_percent_unique_off_target} = $percent_unique_off_target;

    $metric_to_value{wingspan_0_percent_duplication} = $align_stats->{percent_duplicates} || 0;

    #Default coverage depth percentage is zero - there may not be depth information, especially for 30x and 40x
    $metric_to_value{wingspan_0_40_coverage_depth} = $cov_stats->{40}{pc_target_space_covered} || 0;
    $metric_to_value{wingspan_0_30_coverage_depth} = $cov_stats->{30}{pc_target_space_covered} || 0;
    $metric_to_value{wingspan_0_20_coverage_depth} = $cov_stats->{20}{pc_target_space_covered} || 0;
    $metric_to_value{wingspan_0_15_coverage_depth} = $cov_stats->{15}{pc_target_space_covered} || 0;
    $metric_to_value{wingspan_0_10_coverage_depth} = $cov_stats->{10}{pc_target_space_covered} || 0;

    $metric_to_value{wingspan_0_percent_mapped} = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat)->{'reads_mapped_percentage'};

    if ($self->debug) {
        while (my ($metric,$value) = each %metric_to_value) {
            print "Metric for $metric : " . $value . "\n";
        }
    }

    return \%metric_to_value;
}

sub get_metrics_for_qc_data {
    my $self = shift;
    my $build = shift;
    my $qc_file;
    my $compare_snp_result = Genome::Model::Tools::Analysis::LaneQc::CompareSnpsResult->get('users.user_id' => $build->id);

    if($compare_snp_result){
        $qc_file = $compare_snp_result->output_file;
    } else {
        my $qc_dir = $self->qc_directory or return;
        my $dir_name = $build->subject_name;
        ($qc_file) = `ls $qc_dir/$dir_name/*.qc 2>/dev/null`;
        return unless $qc_file;
        chomp $qc_file;
    }

    print "QC File for build ( " . $build->id . " ) : $qc_file\n" if $self->debug;

    my $fh = Genome::Sys->open_file_for_reading($qc_file);

    my @values;
    my $line_number = 1;
    for my $line (<$fh>){
        if(2 == $line_number++){
            $line =~ s/%//g; #Percent symbols break converting this to a number
            @values = split /\s+/, $line;
            last;
        }
    }

    my %metric_to_value;
    $metric_to_value{snps_called} = $values[1] || 0;
    $metric_to_value{with_genotype} = $values[2] || 0;
    $metric_to_value{met_min_depth} = $values[3] || 0;
    $metric_to_value{reference} = $values[4] || 0;
    $metric_to_value{ref_match} = $values[5] || 0;
    $metric_to_value{ref_was_het} = $values[6] || 0;
    $metric_to_value{ref_was_hom} = $values[7] || 0;
    $metric_to_value{variant} = $values[8] || 0;
    $metric_to_value{var_match} = $values[9] || 0;
    $metric_to_value{hom_was_het} = $values[10] || 0;
    $metric_to_value{het_was_hom} = $values[11] || 0;
    $metric_to_value{var_mismatch} = $values[12] || 0;
    $metric_to_value{var_concordance} = $values[13] || 0;
    $metric_to_value{rare_hom_concordance} = $values[14] || 0;
    $metric_to_value{overall_concordance} = $values[15] || 0;

    if ($self->debug) {
        while (my ($metric,$value) = each %metric_to_value) {
            print "Metric for $metric : " . $value . "\n";
        }
    }

    return \%metric_to_value;
}
