package Genome::Model::Tools::BioSamtools::AlignmentSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::AlignmentSummary {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data'
        },
        bed_file => {
            is => 'Text',
            doc => 'A BED file of target regions to evaluate on/off target alignment',
            is_optional => 1,
        },
        wingspan => {
            is => 'Integer',
            doc => 'A wingspan to add to each target region coordinate span',
            is_optional => 1,
        },
        output_file => {
            is => 'Text',
            doc => 'A file path to store tab delimited output',
        },
    ],
};

sub execute {
    my $self = shift;

    my $cmd = $self->execute_path .'/alignment_summary-64.pl '. $self->bam_file;
    my @input_files = ($self->bam_file);
    if ($self->bed_file) {
        $cmd .= ' '. $self->bed_file;
        push @input_files, $self->bed_file;
        if (defined($self->wingspan)) {
            $cmd .= ' '. $self->wingspan;
        }
    }
    $cmd .= ' > '. $self->output_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => \@input_files,
        output_files => [$self->output_file],
    );
    return 1;
}

1;
