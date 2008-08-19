package Genome::Model::Tools::454::Seqclean;

use strict;
use warnings;

use above "Genome";

use Workflow;

use File::Basename;
use Cwd;

class Genome::Model::Tools::454::Seqclean {
    is => ['Command'],
    has => [
            fasta_file => {
                        is => 'string',
                        doc => 'a fasta file path to run seqclean on',
                    },
        ],
    has_optional => [
                     params => {
                                is => 'string',
                                doc => 'a set of params to use with seqclean',
                            },
                     output_file => {
                                     is => 'string',
                                     doc => 'a file path to the seqclean output',
                                 }
                 ],
};

operation_io Genome::Model::Tools::454::Seqclean {
    input => [ 'fasta_file', 'params'],
    output => [ 'output_file' ],
};

sub help_brief {
    "a tool to run seqclean",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools seq-clean ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless (-e $self->fasta_file) {
        die 'Sequence file '. $self->fasta_file .' does not exist';
    }
    unless ($self->output_file) {
        $self->output_file($self->fasta_file .'.clean');
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $cwd = getcwd;

    my $dirname = dirname($self->output_file);
    chdir($dirname) || die("Failed to change directory to '$dirname':  $!");

    my $cmd = 'seqclean '. $self->fasta_file .' -o '. $self->output_file;
    if ($self->params) {
        $cmd .= ' '. $self->params;
    }
    $self->status_message('Running: '. $cmd);

    my $rv = system($cmd);

    chdir($cwd) || die("Failed to change directory to '$cwd':  $!");;

    unless ($rv == 0) {
        $self->error_message("non-zero exit code($rv) returned from command '$cmd'");
        return;
    }

    return 1;
}


1;

