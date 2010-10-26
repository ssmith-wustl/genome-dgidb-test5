package Genome::Model::Event::Build::DeNovoAssembly::Assemble::Soap;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
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

    # check for input fastq files
    $self->status_message('Validating fastq files for libraires');
    my @libraries = $self->build->libraries_with_existing_assembler_input_files;

    if  ( not @libraries ) {
        $self->error_message("No assembler input files were found for libraries");
        return;
    }
    $self->status_message('OK...fastq files for libraires');

    # create config file
    $self->status_message('Creating soap config file');
    my $config = $self->_get_config_for_libraries(@libraries);
    if ( not $config ) {
        $self->error_message('Cannot get config from libraires for '.$self->build->description);
        return;
    }
    if ( not $self->_create_config_file($config) ) {
        $self->error_message("Failed to create config file");
        return;
    }
    $self->status_message('OK...soap config file');

    my %assembler_params = $self->processing_profile->assembler_params_as_hash();
    delete $assembler_params{'insert_size'} if $assembler_params{'insert_size'}; #used in config file not command line

    $self->status_message('Getting number of cpus');
    my $cpus = $self->_get_number_of_cpus;
    return if not $cpus;
    $self->status_message('OK...number of cpus: '.$cpus);

    #create, execute assemble
    $self->status_message('Running soap');
    my $assemble = Genome::Model::Tools::Soap::DeNovoAssemble->create (
        version => $self->processing_profile->assembler_version,
        config_file => $self->build->soap_config_file,
        output_dir_and_file_prefix => $self->build->soap_output_dir_and_file_prefix,
        cpus => $cpus,
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
    $self->status_message('Soap finished successfully');

    return 1;
}

sub _get_config_for_libraries {
    my ($self, @libraries) = @_;

    my $config = "max_rd_len=120\n";
    for my $library ( @libraries ) {
        my $insert_size = $library->{insert_size};# || 320;# die if no insert size
        $config .= <<CONFIG;
[LIB]
avg_ins=$insert_size
reverse_seq=0
asm_flags=3
pair_num_cutoff=2
map_len=60
CONFIG

        if ( exists $library->{paired_fastq_files} ) { 
            $config .= 'q1='.$library->{paired_fastq_files}->[0]."\n";
            $config .= 'q2='.$library->{paired_fastq_files}->[1]."\n";
        }

        if ( exists $library->{fragment_fastq_file} ) {
            $config .= 'q='.$library->{fragment_fastq_file}."\n";
        }
    }

    return $config;
}

sub _create_config_file {
    my ($self, $config) = @_;

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
