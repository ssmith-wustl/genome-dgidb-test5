
package Genome::Model::Tools::Picard::SamToFastq;

use strict;
use warnings FATAL => 'all';

use Genome;

class Genome::Model::Tools::Picard::SamToFastq {
    is  => 'Genome::Model::Tools::Picard',
    has_input => [
        input => {
            is  => 'String',
            doc => 'Input SAM/BAM file to extract reads from. Required.',
        },
        fastq => {
            is          => 'String',
            doc         => 'Output fastq file (single-end fastq or, if paired, first end of the pair fastq). Required.',
        },
        fastq2 => {
            is          => 'String',
            doc         => 'Output fastq file (if paired, second end of the pair fastq). Default value: null.',
            is_optional => 1,
        },
    ],
};

sub help_brief {
    'Tool to create FASTQ file from SAM/BAM using Picard';
}

sub help_detail {
    return <<EOS
    Tool to create FASTQ file from SAM/BAM using Picard.  For Picard documentation of this command see:
    http://picard.sourceforge.net/command-line-overview.shtml#SamToFastq
EOS
}

sub execute {
    my $self = shift;

    my $jar_path = $self->picard_path . '/SamToFastq.jar';
    unless (-e $jar_path) {
        die('Failed to find '. $jar_path .'!  This command may not be available in version '. $self->use_version);
    }

    my $args = '';

    $args .= ' INPUT=' . "'" . $self->input . "'";
    $args .= ' FASTQ=' . "'" . $self->fastq . "'";
    $args .= ' SECOND_END_FASTQ=' . "'" . $self->fastq2 . "'" if ($self->fastq2);

    my $cmd = $jar_path . " net.sf.picard.sam.SamToFastq $args";
    $self->run_java_vm(
        cmd          => $cmd,
        input_files  => [ $self->input ],
        output_files => [ $self->fastq, ( $self->fastq2 ? $self->fastq2 : () ) ],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
__END__

