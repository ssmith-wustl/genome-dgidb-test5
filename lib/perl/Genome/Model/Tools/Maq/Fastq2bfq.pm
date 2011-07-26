package Genome::Model::Tools::Maq::Fastq2bfq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::Fastq2bfq {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use",
                        },
            fastq_file => {
                           doc => 'The input fastq file to bfq format.',
                           is => 'Test',
                       },
            bfq_file => {
                         doc => 'The output bfq format file to create.',
                         is => 'Text',
                     },
        ],
};

sub help_brief {
    'a tool for converting fastq to bfq format using maq fastq2bfq ';
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless (Genome::Sys->validate_file_for_reading($self->fastq_file)) {
        $self->error_message('Failed to validate fastq file for reading:  '. $self->fastq_file);
        return;
    }

    unless (Genome::Sys->validate_file_for_writing($self->bfq_file)) {
        $self->error_message('Failed to validate bfq file for writing:  '. $self->bfq_file);
        return;
    }


    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->maq_path .' fastq2bfq '. $self->fastq_file .' '. $self->bfq_file;
    Genome::Sys->shellcmd(
                                          cmd => $cmd,
                                          input_files => [$self->fastq_file],
                                          output_files => [$self->bfq_file],
                                      );
    return 1;
}

1;
