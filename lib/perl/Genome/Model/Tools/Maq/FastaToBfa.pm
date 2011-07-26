package Genome::Model::Tools::Maq::FastaToBfa;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::FastaToBfa {
    is => 'Genome::Model::Tools::Maq',
    has => [
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use",
                        },
            fasta_file => {
                           doc => 'The input fasta files to convert to bfa.',
                           is => 'Text',
                       },
            bfa_file => {
                           doc => 'The output bfa file to create.',
                           is => 'Text',
                       },
        ],
};

sub help_brief {
    'a tool for converting a fasta file to bfa';
}

sub help_detail {
    return <<"EOS"
        A fasta file must be converted to binary fasta (.bfa) for maq to use as a reference.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    if ($self->__errors__) {
        $self->error_message('Invalid object');
        return;
    }
    unless (Genome::Sys->validate_file_for_reading($self->fasta_file)) {
        $self->error_message('Failed to validate fasta file '. $self->fasta_file .' for reading.');
        die($self->error_message);
    }
    unless (Genome::Sys->validate_file_for_writing($self->bfa_file)) {
        $self->error_message('Failed to validate output bfa file '. $self->bfa_file .' for writing.');
        die($self->error_message);
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = $self->maq_path .' fasta2bfa '. $self->fasta_file .' '. $self->bfa_file;

    unless (Genome::Sys->shellcmd(
                                                  cmd => $cmd,
                                                  input_files => [$self->fasta_file],
                                                  output_files => [$self->bfa_file],
                                              )) {
        $self->error_message('Failed to run shell command '. $cmd);
        return;
    }
    return 1;
}

1;
