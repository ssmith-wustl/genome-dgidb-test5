package Genome::Model::Tools::Capture::GermlineModelGroup2;
use strict;
use warnings;
use Cwd;

class Genome::Model::Tools::Capture::GermlineModelGroup2 {
    is => 'Genome::Command::Base',
    has_input => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            is_optional => 1,
            doc => 'use these models and their samples for QC',
        },
        model_group => {
            is => 'Genome::ModelGroup',
            shell_args_position => 1,
            doc => 'use models from this group and their samples for QC',
        },
        qc_directory => {
            is => 'Text',
            is_optional => 1,
            default => cwd(),
            doc => 'path to gmt capture germline-model-group-qc output',
        },
        output_directory => {
            is => 'Text',
            is_optional => 1,
            default => cwd(),
            doc => 'Dir to store sample/index/pool summaries',
        },
    ],
    doc => 'Summarize information on a model group from germline-model-group and germline-model-group-qc',
};

sub help_brief {
    'Summarize information on a model group from germline-model-group and germline-model-group-qc'
}

sub help_detail{
    help_brief() . "\nExample: gmt capture somatic-model-group2 10407 -qc_dir ./germline-model-group-qc_output"
}

sub help_synopsis {
    help_brief() . "\nExample: gmt capture somatic-model-group2 10407 -qc_dir ./germline-model-group-qc_output"
}

sub execute {
    my $self = shift;
    $self->models([$self->model_group->models]) unless $self->models;
    my $qcdir = $self->qc_directory;

    my $group_id = $self->model_group->id;
    my $subject_summary_file = Genome::Sys->open_file_for_overwriting($self->output_directory . "/$group_id.subject_summary.csv");
    my $index_summary_file = Genome::Sys->open_file_for_overwriting($self->output_directory . "/$group_id.index_summary.csv");
    my $pool_summary_file = Genome::Sys->open_file_for_overwriting($self->output_directory . "/$group_id.pool_summary.csv");

    unless ($self->metrics_exist){
        print "Generating model metrics\n";
        $self->create_model_metrics_for_non_qc_data();
        $self->create_model_metrics_for_qc_data();
    }
    print "Summarizing data\n";

    my (%index_to_builds, %pool_to_builds);

    for my $model ($self->models){
        my $build = $model->last_succeeded_build or next;
        next if $model->subject->name =~ /Pooled_Library/;

        #Take the first instrument_data's index until a decision is made
        #  on how to handle per-sample data, when per-instrument-data data is unavailable
        my $index = (map{$_->index_sequence}$model->instrument_data)[0];
        my $pool = Genome::Model::Command::Services::AssignQueuedInstrumentData->_resolve_pooled_sample_name_for_instrument_data((),$model->instrument_data);

        push @{$index_to_builds{$index}}, $build;
        push @{$pool_to_builds{$pool}}, $build;
    }

    $self->subject_summary($subject_summary_file);
    $self->index_summary($index_summary_file, \%index_to_builds);
    $self->pool_summary($pool_summary_file, \%pool_to_builds);
    return 1;
}

sub common_headers {
    (
        'C-Depth',    # coverage depth
        '%Dup',       # percent duplication
        '%Mapped',
        '%On-target', # % of Unique On-Target Reads
        '%Off-target',# % of Unique Off Target Reads
        'SNPsCalled',
        'WithGenotype',
        'MetMinDepth',
        'Reference',
        'Ref_match',
        'Ref_was_het',
        'Ref_was_hom',
        'Variant',
        'Var_match',
        'Hom_was_het',
        'Het_was_hom',
        'Var_mismatch',
        'VarConcordance',
        'RareHomConcordance',
        'OverallConcordance',
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

sub index_summary {
    my $self = shift;
    my $fh = shift || die;
    my $index_to_builds = shift || die;
    $self->write_index_headers($fh);

    while (my ($index,$builds) = each %$index_to_builds) {
        my (
            $coverage_depth,
            $duplication,
            $mapped,
            $on_target,
            $off_target,
            $snps_called,
            $with_genotype,
            $met_min_depth,
            $reference,
            $ref_match,
            $ref_was_het,
            $ref_was_hom,
            $variant,
            $var_match,
            $hom_was_het,
            $het_was_hom,
            $var_mismatch,
            $var_concordance,
            $rare_hom_concordance,
            $overall_concordance,
        ) = (0)x20;
        for my $build (@$builds) {
            my %metric = map{$_->name,$_->value}$build->metrics;
            $coverage_depth       += $metric{'wingspan_0_20_coverage_depth'} || 0;
            $duplication          += $metric{'wingspan_0_percent_duplication'} || 0;
            $mapped               += $metric{'wingspan_0_percent_mapped'} || 0;
            $on_target            += $metric{'wingspan_0_percent_unique_on_target'} || 0;
            $off_target           += $metric{'wingspan_0_percent_unique_off_target'} || 0;
            $snps_called          += $metric{'snps_called'} || 0;
            $with_genotype        += $metric{'with_genotype'} || 0;
            $met_min_depth        += $metric{'met_min_depth'} || 0;
            $reference            += $metric{'reference'} || 0;
            $ref_match            += $metric{'ref_match'} || 0;
            $ref_was_het          += $metric{'ref_was_het'} || 0;
            $ref_was_hom          += $metric{'ref_was_hom'} || 0;
            $variant              += $metric{'variant'} || 0;
            $var_match            += $metric{'var_match'} || 0;
            $hom_was_het          += $metric{'hom_was_het'} || 0;
            $het_was_hom          += $metric{'het_was_hom'} || 0;
            $var_mismatch         += $metric{'var_mismatch'} || 0;
            $var_concordance      += $metric{'var_concordance'} || 0;
            $rare_hom_concordance += $metric{'rare_hom_concordance'} || 0;
            $overall_concordance  += $metric{'overall_concordance'} || 0;
        }
        print $fh join("\t", (
                $index,
                sprintf ("%.2f",$coverage_depth/@$builds),
                sprintf ("%.2f%%", $duplication/@$builds),
                sprintf ("%.2f%%", $mapped/@$builds),
                sprintf ("%.2f%%", $on_target/@$builds),
                sprintf ("%.2f%%", $off_target/@$builds),
                sprintf ("%.2f",$snps_called/@$builds),
                sprintf ("%.2f",$with_genotype/@$builds),
                sprintf ("%.2f",$met_min_depth/@$builds),
                sprintf ("%.2f",$reference/@$builds),
                sprintf ("%.2f",$ref_match/@$builds),
                sprintf ("%.2f",$ref_was_het/@$builds),
                sprintf ("%.2f",$ref_was_hom/@$builds),
                sprintf ("%.2f",$variant/@$builds),
                sprintf ("%.2f",$var_match/@$builds),
                sprintf ("%.2f",$hom_was_het/@$builds),
                sprintf ("%.2f",$het_was_hom/@$builds),
                sprintf ("%.2f",$var_mismatch/@$builds),
                sprintf ("%.2f",$var_concordance/@$builds),
                sprintf ("%.2f",$rare_hom_concordance/@$builds),
                sprintf ("%.2f",$overall_concordance/@$builds),
            )) . "\n";
    }
}

sub pool_summary {
    my $self = shift;
    my $fh = shift || die;
    my $pool_to_builds = shift || die;
    $self->write_pool_headers($fh);

    while (my ($pool,$builds) = each %$pool_to_builds) {
        my (
            $coverage_depth,
            $duplication,
            $mapped,
            $on_target,
            $off_target,
            $snps_called,
            $with_genotype,
            $met_min_depth,
            $reference,
            $ref_match,
            $ref_was_het,
            $ref_was_hom,
            $variant,
            $var_match,
            $hom_was_het,
            $het_was_hom,
            $var_mismatch,
            $var_concordance,
            $rare_hom_concordance,
            $overall_concordance,
        ) = (0)x20;
        for my $build (@$builds) {
            my %metric = map{$_->name,$_->value}$build->metrics;
            $coverage_depth       += $metric{'wingspan_0_20_coverage_depth'} || 0;
            $duplication          += $metric{'wingspan_0_percent_duplication' || 0};
            $mapped               += $metric{'wingspan_0_percent_mapped'} || 0;
            $on_target            += $metric{'wingspan_0_percent_unique_on_target'} || 0;
            $off_target           += $metric{'wingspan_0_percent_unique_off_target'} || 0;
            $snps_called          += $metric{'snps_called'} || 0;
            $with_genotype        += $metric{'with_genotype'} || 0;
            $met_min_depth        += $metric{'met_min_depth'} || 0;
            $reference            += $metric{'reference'} || 0;
            $ref_match            += $metric{'ref_match'} || 0;
            $ref_was_het          += $metric{'ref_was_het'} || 0;
            $ref_was_hom          += $metric{'ref_was_hom'} || 0;
            $variant              += $metric{'variant'} || 0;
            $var_match            += $metric{'var_match'} || 0;
            $hom_was_het          += $metric{'hom_was_het'} || 0;
            $het_was_hom          += $metric{'het_was_hom'} || 0;
            $var_mismatch         += $metric{'var_mismatch'} || 0;
            $var_concordance      += $metric{'var_concordance'} || 0;
            $rare_hom_concordance += $metric{'rare_hom_concordance'} || 0;
            $overall_concordance  += $metric{'overall_concordance'} || 0;
        }
        print $fh join("\t", (
                $pool,
                sprintf ("%.2f",$coverage_depth/@$builds),
                sprintf ("%.2f%%", $duplication/@$builds),
                sprintf ("%.2f%%", $mapped/@$builds),
                sprintf ("%.2f%%", $on_target/@$builds),
                sprintf ("%.2f%%", $off_target/@$builds),
                sprintf ("%.2f",$snps_called/@$builds),
                sprintf ("%.2f",$with_genotype/@$builds),
                sprintf ("%.2f",$met_min_depth/@$builds),
                sprintf ("%.2f",$reference/@$builds),
                sprintf ("%.2f",$ref_match/@$builds),
                sprintf ("%.2f",$ref_was_het/@$builds),
                sprintf ("%.2f",$ref_was_hom/@$builds),
                sprintf ("%.2f",$variant/@$builds),
                sprintf ("%.2f",$var_match/@$builds),
                sprintf ("%.2f",$hom_was_het/@$builds),
                sprintf ("%.2f",$het_was_hom/@$builds),
                sprintf ("%.2f",$var_mismatch/@$builds),
                sprintf ("%.2f",$var_concordance/@$builds),
                sprintf ("%.2f",$rare_hom_concordance/@$builds),
                sprintf ("%.2f",$overall_concordance/@$builds),
            )) . "\n";
    }
}

sub subject_summary {
    my $self = shift;
    my $fh = shift || die;
    $self->write_subject_headers($fh);

    for my $model ($self->models){
        next if $model->subject->name =~ /Pooled_Library/;
        my $build = $model->last_succeeded_build || next;

        my %metric = map{$_->name,$_->value}$build->metrics;

        #Take the first instrument_data's index until a decision is made
        #  on how to handle per-sample data, when per-instrument-data data is unavailable
        my $index = (map{$_->index_sequence}$model->instrument_data)[0];
        my $pool = Genome::Model::Command::Services::AssignQueuedInstrumentData->_resolve_pooled_sample_name_for_instrument_data((),$model->instrument_data);
        my @libraries = map{$_->name}$model->subject->libraries;
        my $libraries;
        if(@libraries){
            $libraries = join ',', @libraries;
        } else {
            $libraries = '-';
        }

        #add model->instrument_data->lane
        print $fh join("\t", (
                $model->id,
                $build->id,
                $model->subject->name,
                $libraries,
                $index,
                $pool,
                $metric{'wingspan_0_20_coverage_depth'} || '-',
                $metric{'wingspan_0_percent_duplication'} ? sprintf ("%.1f%%", $metric{'wingspan_0_percent_duplication'}) : '-',
                sprintf ("%.2f%%", $metric{'wingspan_0_percent_mapped'}) || '-',
                sprintf ("%.2f%%", $metric{'wingspan_0_percent_unique_on_target'}) || '-',
                sprintf ("%.2f%%", $metric{'wingspan_0_percent_unique_off_target'}) || '-',
                $metric{'snps_called'} || '-',
                $metric{'with_genotype'} || '-',
                $metric{'met_min_depth'} || '-',
                $metric{'reference'} || '-',
                $metric{'ref_match'} || '-',
                $metric{'ref_was_het'} || '-',
                $metric{'ref_was_hom'} || '-',
                $metric{'variant'} || '-',
                $metric{'var_match'} || '-',
                $metric{'hom_was_het'} || '-',
                $metric{'het_was_hom'} || '-',
                $metric{'var_mismatch'} || '-',
                $metric{'var_concordance'} || '-',
                $metric{'rare_hom_concordance'} || '-',
                $metric{'overall_concordance'} || '-',
            )) . "\n";
    }
}

sub create_model_metrics_for_non_qc_data {
    my $self = shift;
    for my $model ($self->models){
        next if grep {$_->index_sequence eq 'unknown'} $model->instrument_data;
        my $build = $model->last_succeeded_build or next;
        my %metrics = map{$_->name,$_->value}$build->metrics;

        my $unique_on_target = $metrics{wingspan_0_unique_target_aligned_bp};
        my $duplicate_on_target = $metrics{wingspan_0_duplicate_target_aligned_bp};
        my $unique_off_target = $metrics{wingspan_0_unique_off_target_aligned_bp};
        my $duplicate_off_target = $metrics{wingspan_0_duplicate_off_target_aligned_bp};
        my $unaligned = $metrics{wingspan_0_total_unaligned_bp};

        my $total = $unique_on_target+$duplicate_on_target+$unique_off_target+$duplicate_off_target+$unaligned;
        my $percent_unique_on_target = $unique_on_target/$total*100;
        my $percent_duplicate_on_target = $duplicate_on_target/$total*100;
        my $percent_unique_off_target = $unique_off_target/$total*100;
        my $percent_duplicate_off_target = $duplicate_off_target/$total*100;
        my $percent_unaligned = $unaligned/$total*100;

        my $stats = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($build->whole_rmdup_bam_flagstat_file);

        $build->add_metric(name => 'wingspan_0_20_coverage_depth', value => $build->coverage_stats_summary_hash_ref->{0}{20}{mean_depth}) unless defined $metrics{'wingspan_0_20_coverage_depth'};
        if (my ($dup) = map {$metrics{$_}} grep {$_ =~ /PERCENT_DUPLICATION/} keys %metrics){
            $build->add_metric(name => 'wingspan_0_percent_duplication', value => $dup * 100) unless defined $metrics{'wingspan_0_percent_duplication'};
        }
        else{
            $build->add_metric(name => 'wingspan_0_percent_duplication', value => 0) unless defined $metrics{'wingspan_0_percent_duplication'};
        }
        $build->add_metric(name => 'wingspan_0_percent_mapped', value => $stats->{reads_mapped_percentage}) unless defined $metrics{'wingspan_0_percent_mapped'};
        $build->add_metric(name => 'wingspan_0_percent_unique_on_target', value => $percent_unique_on_target) unless defined $metrics{'wingspan_0_percent_unique_on_target'};
        $build->add_metric(name => 'wingspan_0_percent_unique_off_target', value => $percent_unique_off_target) unless defined $metrics{'wingspan_0_percent_unique_off_target'};
    }
}

sub create_model_metrics_for_qc_data {
    my $self = shift;
    my $qc_dir = $self->qc_directory;
    my @dir_names = `ls $qc_dir`;

    for my $dir_name (@dir_names){
        chomp $dir_name;
        my $sample = $dir_name;
        my ($qc_file) = `ls $qc_dir/$dir_name/*.qc`;
        chomp $qc_file;

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

        my $model = Genome::Model->get(id => [map{$_->id}$self->models], subject_name => $sample) || next;
        my $build = $model->last_succeeded_build;
        my %metrics = map{$_->name,$_->value}$build->metrics;

        $build->add_metric(name => 'snps_called', value => $values[1]) unless defined $metrics{'snps_called'};
        $build->add_metric(name => 'with_genotype', value => $values[2]) unless defined $metrics{'with_genotype'};
        $build->add_metric(name => 'met_min_depth', value => $values[3]) unless defined $metrics{'met_min_depth'};
        $build->add_metric(name => 'reference', value => $values[4]) unless defined $metrics{'reference'};
        $build->add_metric(name => 'ref_match', value => $values[5]) unless defined $metrics{'ref_match'};
        $build->add_metric(name => 'ref_was_het', value => $values[6]) unless defined $metrics{'ref_was_het'};
        $build->add_metric(name => 'ref_was_hom', value => $values[7]) unless defined $metrics{'ref_was_hom'};
        $build->add_metric(name => 'variant', value => $values[8]) unless defined $metrics{'variant'};
        $build->add_metric(name => 'var_match', value => $values[9]) unless defined $metrics{'var_match'};
        $build->add_metric(name => 'hom_was_het', value => $values[10]) unless defined $metrics{'hom_was_het'};
        $build->add_metric(name => 'het_was_hom', value => $values[11]) unless defined $metrics{'het_was_hom'};
        $build->add_metric(name => 'var_mismatch', value => $values[12]) unless defined $metrics{'var_mismatch'};
        $build->add_metric(name => 'var_concordance', value => $values[13]) unless defined $metrics{'var_concordance'};
        $build->add_metric(name => 'rare_hom_concordance', value => $values[14]) unless defined $metrics{'rare_hom_concordance'};
        $build->add_metric(name => 'overall_concordance', value => $values[15]) unless defined $metrics{'overall_concordance'};
    }
}

sub metrics_exist {
    my $self = shift;
    for my $model ($self->models){
        next if grep {$_->index_sequence eq 'unknown'} $model->instrument_data;
        my $build = $model->last_succeeded_build or next;
        my %metrics = map{$_->name,$_->value}$build->metrics;
        return 0 unless(
            defined($metrics{'snps_called'}) and
            defined($metrics{'with_genotype'}) and
            defined($metrics{'met_min_depth'}) and
            defined($metrics{'reference'}) and
            defined($metrics{'ref_match'}) and
            defined($metrics{'ref_was_het'}) and
            defined($metrics{'ref_was_hom'}) and
            defined($metrics{'variant'}) and
            defined($metrics{'var_match'}) and
            defined($metrics{'hom_was_het'}) and
            defined($metrics{'het_was_hom'}) and
            defined($metrics{'var_mismatch'}) and
            defined($metrics{'var_concordance'}) and
            defined($metrics{'rare_hom_concordance'}) and
            defined($metrics{'overall_concordance'}) and
            defined($metrics{'wingspan_0_20_coverage_depth'}) and
            defined($metrics{'wingspan_0_percent_duplication'}) and
            defined($metrics{'wingspan_0_percent_mapped'}) and
            defined($metrics{'wingspan_0_percent_unique_on_target'}) and
            defined($metrics{'wingspan_0_percent_unique_off_target'})
        );
    }
    return 1;
}
