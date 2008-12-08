package Genome::Model::Tools::Velvet::Hash;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Velvet::Hash {
    is           => 'Command',
    has_many     => [
        file_names  => {
            is      => 'String', 
            doc     => 'input file name(s)',
        }
    ],
    has_optional => [
        directory   => {
            is      => 'String', 
            doc     => 'directory name for output files, default is ./velvet_run',
            default => 'velvet_run',
        },
        hash_length => {
            is      => 'Integer', 
            doc     => 'odd integer (if even, will be decremented) <= 31, if above, will be reduced, default: 23',
            default => 23,
        },
        file_format => {
            is      => 'String',
            doc     => 'input file format: fasta, fastq, fasta.gz, fastq.gz, eland, gerald. default: fasta',
            default => 'fasta',
        },
        read_type   => {
            is      => 'String',
            doc     => 'read type: short, shortPaired, short2, shortPaired2, long, longPaired. default: short',
            default => 'short',
        },
    ],
};
        

sub help_brief {
    "This tool runs velveth",
}


sub help_synopsis {
    return <<"EOS"
gt velvet hash --file_names name [--directory dir --hash_length 21 --fire_format fastq --read_type short]
EOS
}


sub help_detail {
    return <<EOS
Velveth constructs the dataset for the following program, velvetg, and
indicate to the system what each sequence file represents.Velveth takes 
in a number of sequence files, produces a hashtable, then outputs two files 
in an output directory (creating it if necessary), Sequences and Roadmaps, 
which are necessary to velvetg.
EOS
}


sub create {
    my $class = shift;
    
    my $self  = $class->SUPER::create(@_);
    my $dir   = $self->directory;

    for my $file ($self->file_names) {
        unless (-s $file) {
            $self->error_message("Input file: $file, not existing or is empty");
            return;
        }
    }
    
    if (-d $dir) {
        $self->warning_message("velveth will overwrite output in directory: $dir");
    }
    else {
        mkdir $dir, 0777;
        unless (-d $dir) {
            $self->error_message("Fail to create output directory: $dir");
            return;
        }
    }
    
    return $self;
}


sub execute {
    my $self = shift;
    
    my $files = join ' ', $self->file_names;
    
    my $command = sprintf(
        'velveth %s %d -%s -%s %s',
        $self->directory,
        $self->hash_length,
        $self->file_format,
        $self->read_type,
        $files,
    );
    
    if (system $command) {
        $self->error_message('velveth failed.');
        return;
    }

    return 1;
}


1;
#$HeadURL$
#$Id$

