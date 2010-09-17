package Genome::Model::Build::DeNovoAssembly::Soap;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::DeNovoAssembly::Soap {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files >#
sub soap_output_dir_and_file_prefix {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix;
}

sub file_prefix {
    return $_[0]->model->subject_name.'_'.$_[0]->center_name;
}

sub assembler_input_files {
    return map { $_[0]->$_ } (qw/ end_one_fastq_file end_two_fastq_file /);
}

sub end_one_fastq_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.input_1.fastq';
}

sub end_two_fastq_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.input_2.fastq';
}

sub soap_config_file {
    return $_[0]->data_directory.'/config_file';
}

sub soap_scaffold_sequence_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.scafSeq';
}

sub soap_output_file_for_ext {
    return $_[0]->soap_output_dir_and_file_prefix.'.'.$_[1];
}

1;

