package Genome::Model::Build::DeNovoAssembly::Soap;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::DeNovoAssembly::Soap {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files >#
sub assembler_input_files {
    return map { $_[0]->$_ } (qw/ end_one_fastq_file end_two_fastq_file /);
}

sub end_one_fastq_file { 
    return $_[0]->data_directory.'/1_fastq';
}

sub end_two_fastq_file {
    return $_[0]->data_directory.'/2_fastq';
}

sub soap_config_file {
    return $_[0]->data_directory.'/config_file';
}

sub soap_output_dir_and_file_prefix {
    return $_[0]->data_directory.'/Assembly';
}

sub soap_scaffold_sequence_file {
    return $_[0]->data_directory.'/Assembly.scafSeq';
}

1;

