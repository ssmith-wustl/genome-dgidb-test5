package Genome::Model::Build::DeNovoAssembly::Velvet;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';

class Genome::Model::Build::DeNovoAssembly::Velvet {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files >#
sub assembler_input_files {
    return $_[0]->collated_fastq_file;
}

sub collated_fastq_file {
    return $_[0]->data_directory.'/collated.fastq';
}

sub assembly_afg_file {
    return $_[0]->data_directory.'/velvet_asm.afg';
}

sub contigs_fasta_file {
    return $_[0]->data_directory.'/contigs.fa';
}

sub sequences_file {
    return $_[0]->data_directory.'/Sequences';
}

sub velvet_fastq_file {
    return $_[0]->data_directory.'/velvet.fastq';
}

sub velvet_ace_file {
    return $_[0]->data_directory.'/edit_dir/velvet_asm.ace';
}

sub ace_file {
    return $_[0]->edit_dir.'/velvet_asm.ace';
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly/Velvet.pm $
#$Id: Velvet.pm 61146 2010-07-20 21:19:56Z kkyung $
