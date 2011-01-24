package Genome::Model::Tools::Maq::Sol2sanger;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::Sol2sanger {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use",
                        },
            solexa_fastq_file => {
                                  doc => 'The input solexa fastq file to convert quality scores.',
                                  is => 'Test',
                              },
            sanger_fastq_file => {
                                  doc => 'The output sanger fastq file to create.',
                                  is => 'Text',
                              },
        ],
};

sub help_brief {
    'a tool for converting solexa quality scores using maq sol2sanger ';
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless (Genome::Sys->validate_file_for_reading($self->solexa_fastq_file)) {
        $self->error_message('Failed to validate solexa fastq file for reading:  '. $self->solexa_fastq_file);
        return;
    }

    unless (Genome::Sys->validate_file_for_writing($self->sanger_fastq_file)) {
        $self->error_message('Failed to validate sanger fastq file for writing:  '. $self->sanger_fastq_file);
        return;
    }


    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->maq_path .' sol2sanger '. $self->solexa_fastq_file .' '. $self->sanger_fastq_file;
    Genome::Sys->shellcmd(
                                          cmd => $cmd,
                                          input_files => [$self->solexa_fastq_file],
                                          output_files => [$self->sanger_fastq_file],
                                      );
    return 1;
}

1;
