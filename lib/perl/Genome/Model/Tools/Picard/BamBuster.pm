
package Genome::Model::Tools::Picard::BamBuster;

use strict;
use warnings FATAL => 'all';

use Genome;

class Genome::Model::Tools::Picard::BamBuster {
    is  => 'Genome::Model::Tools::Picard',
    has_input => [
        input => {
            is  => 'String',
            doc => 'Input SAM/BAM file to extract reads from. Required.',
        },
        output_directory => {
            is          => 'String',
            doc         => 'Output directory where data will be dumped.  In here will be subdirectories for each library',
        },
    ],
};

sub help_brief {
    'Tool to break apart BAMs into smaller BAMs based on their component read groups'
}

sub help_detail {
    return <<EOS
Tool to break apart BAMs into smaller BAMs based on their component read groups
EOS
}

sub execute {
    my $self = shift;

    my $picard_version = $self->use_version;
    
    if ($self->use_version < 1.31)  {
        $self->error_message("you must use picard 1.31 or better to run this tool");
        return;
    }

    if (!-d $self->output_directory) {
        $self->error_message("you must specify an output directory that exists and is writable");
        return;
    }

    my $picard_dir = $self->picard_path;
    my $picard_jar_path = $picard_dir . "/sam-".$picard_version.".jar";
    my $sam_jar_path = $picard_dir . "/picard-".$picard_version.".jar";
    my $tool_jar_path = $self->class->base_dir . "/BamBuster.jar";

    my $cp = join ":", ($picard_jar_path, $sam_jar_path, $tool_jar_path);

    my $jvm_options = $self->additional_jvm_options || '';
    my $java_vm_cmd = 'java -Xmx'. $self->maximum_memory .'g -XX:MaxPermSize=' . $self->maximum_permgen_memory . 'm ' . $jvm_options . ' -cp '. $cp . ' edu.wustl.genome.samtools.BamBuster ';
    

    my $args = '';

    $args .= ' INPUT=' . "'" . $self->input . "'";
    $args .= ' OUTPUT_DIR=' . "'" . $self->output_directory. "'";

    $java_vm_cmd .= $args;

    print $java_vm_cmd . "\n";

    $self->run_java_vm(
        cmd          => $java_vm_cmd,
        input_files  => [ $self->input ],
        skip_if_output_is_present => 0,
    );
    return 1;
}


1;
__END__

