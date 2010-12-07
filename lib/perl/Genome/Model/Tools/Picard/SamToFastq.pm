
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
        fragment_fastq => {
            is          => 'String',
            doc         => 'Output fastq file for bams which contain a mix of fragments & pairs -- required if paired',
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

    my $picard_version = $self->use_version;

    if ($self->fastq2 && !$self->fragment_fastq) {
        $self->error_message("you must specify a fragment fastq file output if you are using pairs!");
        return;
    }

    my $picard_dir = $self->picard_path;
    my $picard_jar_path = $picard_dir . "/sam-".$picard_version.".jar";
    my $sam_jar_path = $picard_dir . "/picard-".$picard_version.".jar";
    my $tool_jar_path = $self->class->base_dir . "/GCSamToFastq.jar";

    my $cp = join ":", ($picard_jar_path, $sam_jar_path, $tool_jar_path);

    my $jvm_options = $self->additional_jvm_options || '';
    my $java_vm_cmd = 'java -Xmx'. $self->maximum_memory .'g -XX:MaxPermSize=' . $self->maximum_permgen_memory . 'm ' . $jvm_options . ' -cp '. $cp . ' edu.wustl.genome.samtools.GCSamToFastq ';
    

    my $args = '';

    $args .= ' INPUT=' . "'" . $self->input . "'";
    $args .= ' FASTQ=' . "'" . $self->fastq . "'";
    $args .= ' SECOND_END_FASTQ=' . "'" . $self->fastq2 . "'" if ($self->fastq2);
    $args .= ' FRAGMENT_FASTQ=' . "'" . $self->fragment_fastq. "'" if ($self->fragment_fastq);

    $java_vm_cmd .= $args;

    print $java_vm_cmd . "\n";

    my @output_files = ($self->fastq);
    push @output_files, $self->fastq2 if $self->fastq2;
#    push @output_files, $self->fragment_fastq if $self->fragment_fastq;

    $self->run_java_vm(
        cmd          => $java_vm_cmd,
        input_files  => [ $self->input ],
#        output_files => \@output_files,
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
__END__

