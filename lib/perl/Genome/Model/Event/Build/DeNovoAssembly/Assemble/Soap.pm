package Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
};

sub bsub_rusage {
    my $self = shift;

    # Get cpus from assembler params
    my %assembler_params = $self->processing_profile->assembler_params_as_hash;
    my $cpus_option = ( exists $assembler_params{cpus} ) ? '-n '.$assembler_params{cpus}.' ': '';

    # TODO calculate mem, using 10G for now
    my $mem = 10000;
    
    return $cpus_option."-R 'select[type==LINUX64 && mem>$mem] span[hosts=1] rusage[mem=$mem]' -M $mem".'000';
}

sub execute {
    my $self = shift;

    #check for input fastq files
    unless (-s $self->build->end_one_fastq_file) {
        $self->error_message("Failed to find fastq file of 1 end reads");
        return;
    }
    unless (-s $self->build->end_two_fastq_file) {
        $self->error_message("Failed to find fastq file of 2 end reads");
        return;
    }

    #create config file;
    unless ($self->create_config_file) {
        $self->error_message("Failed to create config file");
        return;
    }

    my %assembler_params = $self->processing_profile->assembler_params_as_hash();

    #create, execute assemble
    my $assemble = Genome::Model::Tools::Soap::DeNovoAssemble->create (
        version => $self->processing_profile->assembler_version,
        config_file => $self->build->soap_config_file,
        output_dir_and_file_prefix => $self->build->soap_output_dir_and_file_prefix,
        %assembler_params,
    );
    unless ($assemble) {
        $self->error_message("Failed to create de-novo-assemble");
        return;
    }
    unless ($assemble->execute) {
        $self->error_message("Failed to execute de-novo-assemble execute");
        return;
    }

    return 1;
}

sub create_config_file {
    my $self = shift;

    unlink $self->build->soap_config_file if -s $self->build->soap_config_file;

    my $fh = Genome::Utility::FileSystem->open_file_for_writing($self->build->soap_config_file);

    #TODO - 
    $fh->print("max_rd_len=100\n".
        "[LIB]\n".
        "avg_ins=202\n".
        "reverse_seq=0\n".
        "asm_flags=3\n".
        "rd_len_cutoff=100\n".
        "rank=1\n".
        "pair_num_cutoff=4\n".
        "map_len=34\n".    #TODO - here and above .. not default params .. will have to change bases on pp
        "q1=".$self->build->end_one_fastq_file."\n".
        "q2=".$self->build->end_two_fastq_file."\n");
    $fh->close;

    return 1;
}

1;
