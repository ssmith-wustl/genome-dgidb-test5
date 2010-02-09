package Genome::Model::Tools::Picard::MarkDuplicates;

use strict;
use warnings;

use Genome;

my $DEFAULT_ASSUME_SORTED = 1;
my $DEFAULT_REMOVE_DUPLICATES = 0;

class Genome::Model::Tools::Picard::MarkDuplicates {
    is  => 'Genome::Model::Tools::Picard',
    has_input => [
        input_file => {
            is  => 'String',
            doc => 'The SAM/BAM files to merge.  File type is determined by suffix.',
        },
        output_file => {
            is  => 'String',
            doc => 'The resulting merged SAM/BAM file.  File type is determined by suffix.',
        },
        metrics_file => {
            is  => 'String',
            doc => 'File to write duplication metrics to.',
        },
        assume_sorted => {
            is  => 'Integer',
            valid_values => [1, 0],
            doc => 'Assume the input data is sorted.  default_value='. $DEFAULT_ASSUME_SORTED,
            default_value => $DEFAULT_ASSUME_SORTED,
            is_optional => 1,
        },
        remove_duplicates => {
            is => 'Integer',
            valid_values => [1, 0],
            doc => 'Merge the seqeunce dictionaries. default_value='. $DEFAULT_REMOVE_DUPLICATES,
            default_value => $DEFAULT_REMOVE_DUPLICATES,
            is_optional => 1,
        },
    ],
};

sub help_brief {
    'Tool to mark or remove duplicate reads from a SAM/BAM file.';
}

sub help_detail {
    return <<EOS
    Examines aligned records in the supplied SAM or BAM file to locate duplicate molecules.
    All records are then written to the output file with the duplicate records flagged.
    For Picard documentation of this command see:
    http://picard.sourceforge.net/command-line-overview.shtml#MarkDuplicates
EOS
}

sub execute {
    my $self = shift;


    my $dedup_cmd = $self->picard_path .'/MarkDuplicates.jar net.sf.picard.sam.MarkDuplicates';
    if ($self->remove_duplicates) {
        $dedup_cmd .= ' REMOVE_DUPLICATES=true';
    } else {
        $dedup_cmd .= ' REMOVE_DUPLICATES=false';
    }
    if ($self->assume_sorted) {
        $dedup_cmd .= ' ASSUME_SORTED=true';
    } else {
        $dedup_cmd .= ' ASSUME_SORTED=false';
    }
    $dedup_cmd .= ' OUTPUT='. $self->output_file .' METRICS_FILE='. $self->metrics_file .' INPUT='. $self->input_file;
    $self->run_java_vm(
        cmd => $dedup_cmd,
        input_files => [$self->input_file],
        output_files => [$self->output_file, $self->metrics_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
