package Genome::Model::Tools::WuBlast::Xdformat::Create;

use strict;
use warnings;

use Genome;

require File::Basename;

class Genome::Model::Tools::WuBlast::Xdformat::Create {
    is => 'Genome::Model::Tools::WuBlast::Xdformat',
    has => [
    database => {
        is => 'String',
        is_optional => 0,
        is_input => 1,
        doc => 'the path to a new or existing database',
    },
    overwrite_db => {
        is => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => 'If existing, remove the database files to be made by xdformat',
    },
    ],
    has_many => [
    fasta_files => {
        is => 'String',
        is_optional => 0,
        is_input => 1,
        doc => 'a list of paths to fasta sequence files',
    },
    ],
};

sub help_brief {
    "a genome-model tool for creating a nucleotide wu-blastable database",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast xdformat create --database --fasta-files
EOS
}

sub help_detail {
    return <<EOS
EOS
}

my @xdformat_extentions = (qw/ xnd xns xnt /);
sub xdformat_files {
    my $self = shift;
    
    return map { sprintf('%s.%s', $self->database, $_) } @xdformat_extentions;
}

sub _verify_xdformat_files {
    return grep { -e $_ } $_[0]->xdformat_files;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    # Check FASTAs
    unless ( $self->fasta_files ) {
        $self->error_message("No fasta files to create database from");
        return;
    }

    my @missing_fastas;
    for my $fasta_file ( $self->fasta_files ) {
        push @missing_fastas, $fasta_file unless -e $fasta_file;
    }

    if ( @missing_fastas ) {
        $self->error_message(
            sprintf(
                'FASTA files (%s) do not exist',
                join(', ', @missing_fastas),
            )
        );
        return;
    }

    # Handle DB
    if ( $self->overwrite_db ) {
        for my $file ( $self->xdformat_files ) {
            unlink $file if -e $file;
        }
    }
    else {
        my @existing_files = $self->_verify_xdformat_files;
        if ( @existing_files ) { 
            $self->error_message(
                sprintf(
                    'Files (%s) for database (%s) already exists, and overwriting the database files was not true',
                    join(', ', @existing_files),
                    $self->database,
                )
            );
            return;
        }
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $cmd = 'xdformat -n -o '.$self->database.' '.join(' ', $self->fasta_files);
    $self->status_message('Running: '.$cmd);
    my $rv = system($cmd);
    unless ( $rv == 0 ) {
        $self->error_message("Non zero return value ($rv) from command xdformat");
        return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
