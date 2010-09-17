package Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap;

use strict;
use warnings;

use Genome;

use Regexp::Common;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
};

sub bsub_rusage {
    my $self = shift;

    # TODO calculate mem, using 30G for now
    my $mem = 30000;
    
    return "-n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>$mem] rusage[mem=$mem]' -M $mem".'000';
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

    # FIXME get processor from LSF, if appliclble
    my $cpus = $self->_get_number_of_cpus;
    return if not $cpus;

    #create, execute assemble
    my $assemble = Genome::Model::Tools::Soap::DeNovoAssemble->create (
        version => $self->processing_profile->assembler_version,
        config_file => $self->build->soap_config_file,
        output_dir_and_file_prefix => $self->build->soap_output_dir_and_file_prefix,
        #cpus => $cpus,
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

    my $insert_size = $self->build->calculate_average_insert_size;
    $insert_size = 320 if not defined $insert_size;
    my $fastq_1 = $self->build->end_one_fastq_file;
    my $fastq_2 = $self->build->end_two_fastq_file;
    my $config = <<CONFIG;
max_rd_len=120
[LIB]
avg_ins=$insert_size
reverse_seq=0
asm_flags=3
pair_num_cutoff=2
map_len=60
q1=$fastq_1
q2=$fastq_2
CONFIG

    my $config_file = $self->build->soap_config_file;
    unlink $config_file if -e $config_file;
    my $fh;
    eval {
        $fh = Genome::Utility::FileSystem->open_file_for_writing($config_file);
    };
    if ( not defined $fh ) {
        $self->error_message("Cannot open soap config file ($config_file) for writing: $@");
        return;
    }
    $fh->print($config);
    $fh->close;

    return 1;
}

sub _get_number_of_cpus {
    my $self = shift;

    return 1 if not defined $ENV{LSB_MCPU_HOSTS};

    my @tokens = split(/\s/, $ENV{LSB_MCPU_HOSTS});
    my $cpus = 0;
    if ( not @tokens ) {
        $self->error_message('Could not split LSB_MCPU_HOSTS: '.$ENV{LSB_MCPU_HOSTS});
        return;
    }

    for ( my $i = 1; $i <= @tokens; $i += 2 ) {
        if ( $tokens[$i] !~ /^$RE{num}{int}$/ ) {
            $self->error_message('Error parsing LSB_MCPU_HOSTS ('.$ENV{LSB_MCPU_HOSTS}.'), number of cpus is not an int: '.$tokens[$i]);
            return;
        }
        $cpus += $tokens[$i];
    }

    if ( $cpus == 0 ) {
        $self->error_message('Could not get the number of cpus from LSB_MCPU_HOSTS: '.$ENV{LSB_MCPU_HOSTS});
        return;
    }

    return $cpus;
}

1;
