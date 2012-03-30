package Genome::Model::MutationalSignificance::Command::CreateROI;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateROI {
    is => ['Command::V2'],
    has_input => [
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation'
        },
        excluded_reference_sequence_patterns => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => "Exclude transcripts on these reference sequences",
        },
        included_feature_type_patterns => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Include only entries that match one of these patterns',
        },
        condense_feature_name => {
            is => 'Boolean',
            doc => 'Use only gene name as feature name',
            default_value => 1,
        },
        flank_size => {
            is => 'Integer',
            doc => 'Add this number of base pairs on each side of the feature', #to do: check this
            default_value => 0,
        },
        one_based => {
            is => 'Boolean',
            default_value => 1,
        },
    ],
    has_output => [
        roi_path => {
            is => 'String',
        },
    ],
};

sub execute {
    my $self = shift;

    my $feature_list = $self->annotation_build->get_or_create_roi_bed;

    unless ($feature_list) {
        $self->error_message('Base ROI file not available from annotation build '.$self->annotation_build->id);
        return;
    }

    my $name = $feature_list->name;
    my $exclude_patterns;
    my $include_patterns;

    if ($self->excluded_reference_sequence_patterns) {
        $exclude_patterns = join("|", $self->excluded_reference_sequence_patterns);
        $name = join("_", $name, $exclude_patterns);
        $self->status_message('Excluding features that match the pattern: '.$exclude_patterns);
    }

    if ($self->included_feature_type_patterns) {
        $include_patterns = join("|", $self->included_feature_type_patterns);
        $name = join("_", $name, $include_patterns);
        $self->status_message('Including only features that match the pattern: '.$include_patterns);
    }

    if ($self->condense_feature_name) {
        $name = $name."_gene-name-only";
    }

    if ($self->flank_size > 0 ) {
        $name = $name."_".$self->flank_size."bp-flank";
    }

    my $customized_roi = Genome::FeatureList->get(subject => $self->annotation_build,
                                                  name => $name,
    );

    if ($customized_roi) {
        $self->roi_path($customized_roi->file_path);
        $self->status_message('Using ROI file: '.$self->roi_path);
        return 1;
    }


    my $reference_index = $self->annotation_build->reference_sequence->data_directory."/all_sequences.fa.fai";
    my %chrom_stop = map {chomp; split(/\t/)} `cut -f 1,2 $reference_index`;

    my $in_file = Genome::Sys->open_file_for_reading($feature_list->file_path); 
    my ($out_file, $out) = Genome::Sys->create_temp_file;
    while(my $line = <$in_file>) {
        chomp $line;
        my @fields = split(/\t/, $line);
        if ($self->one_based) {
            $fields[1]++;
        }
        if ($exclude_patterns) {
            if ($fields[0] =~ /$exclude_patterns/) {
                next;
            }
        }
        if ($include_patterns) {
            if (!($fields[3] =~ /$include_patterns/)) {
                next;
            }
        }
        if ($self->condense_feature_name) {
            my @name_fields = split /:/, $fields[3];
            $fields[3] = $name_fields[0];
        }
        if ($self->flank_size > 0) {
            if ($fields[1] > $chrom_stop{$fields[0]}) {
                next;
            }
            $fields[1] -= $self->flank_size;
            $fields[2] += $self->flank_size;
            $fields[1] = 1 if ($fields[1] < 1);
            $fields[2] = $chrom_stop{$fields[0]} if ($fields[2] > $chrom_stop{$fields[0]});
        }
        print $out_file join("\t", @fields)."\n";
    }

    close($out_file);

    my $sorted_out = Genome::Sys->create_temp_file_path;

    my $rv = Genome::Model::Tools::Joinx::Sort->execute(input_files => [$out],
                                                        unique => 1,
                                                        output_file => $sorted_out );

    my $file_content_hash = Genome::Sys->md5sum($sorted_out);

    my $format;
    if ($self->one_based) {
        $format = '1-based';
    }
    else {
        $format = 'true-BED';
    }

    $customized_roi = Genome::FeatureList->create(
        name => $name,
        format => $format,
        file_content_hash => $file_content_hash,
        subject => $self->annotation_build,
        reference => $self->annotation_build->reference_sequence,
        file_path => $sorted_out,
        content_type => 'roi',
        description => 'Created by genome model mutational-significance create-roi',
        source => 'WUTGI',
    );

    if (!$customized_roi) {
        $self->error_message("Failed to create ROI file");
        return;
    }

    $self->roi_path($customized_roi->file_path);

    $self->status_message('Created ROI file: '.$self->roi_path);

    return 1;
}

1;
