package Genome::FeatureList::Command::DumpMergedList;

use strict;
use warnings;

use Genome;


class Genome::FeatureList::Command::DumpMergedList {
    is => 'Genome::Command::Base',
    has_input => [
        feature_list => { is => 'Genome::FeatureList', doc => 'The feature list to be dumped', shell_args_position => 1 },
        output_path => {
            is => 'Text',
            is_optional => 1,
            doc => 'Where to save the merged BED file.  Will print to STDOUT if not provided.',
            shell_args_position => 2,
        },
        alternate_reference => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'To convert the coordinates of the BED file to a different reference',
            is_optional => 1,
        }
    ]
};

sub help_brief {
    "Dump the merged BED file for a feature-list.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 gmt feature-list dump-merged-list --feature-list 'example' --output-path ~/example.merged.bed
EOS
}

sub help_detail {                           
    return <<EOS 
Produces a BED file in the standard (true-BED) format, with overlapping features merged.  If an output_path is provided,
this bed file will be saved there.  Otherwise it will be printed to the standard output.
EOS
}

sub execute {
    my $self = shift;
    my $feature_list = $self->feature_list;

    my $bed;

    my $alternate_reference = $self->alternate_reference;
    if($alternate_reference) {
        $bed = $feature_list->converted_bed_file($alternate_reference);
    } else {
        $bed = $feature_list->merged_bed_file;
    }

    if($self->output_path) {
        Genome::Sys->copy_file($bed, $self->output_path);
    } else {
        Genome::Sys->shellcmd(cmd => "cat $bed", input_files => [$bed]);
    }

    return 1;
}

1;
