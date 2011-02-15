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
sub existing_assembler_input_files {
    my $self = shift;

    my $collated_fastq_file = $self->collated_fastq_file;
    return $collated_fastq_file if -s $collated_fastq_file;

    return;
}

sub collated_fastq_file {
    return $_[0]->data_directory.'/collated.fastq';
}

sub read_processor_output_files_for_instrument_data {
    return $_[0]->collated_fastq_file;
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

sub _additional_metrics {
    my ($self, $metrics) = @_;

    my $kmer_used = $self->assembler_kmer_used;
    return if not defined $kmer_used;

    $metrics->{assembler_kmer_used} = $kmer_used;

    return 1;
}

#< Kmer Used in Assembly >#
sub assembler_kmer_used {
    my $self = shift;

    my $velvet_log = $self->data_directory.'/Log';
    my $fh = eval{ Genome::Sys->open_file_for_reading($velvet_log); };
    if ( not $fh ) {
        $self->error_message("Cannot open velvet log file ($velvet_log) to get assembler kmer used.");
        return;
    }

    $fh->getline;
    my $line = $fh->getline;
    return if not $line;

    $line =~ s/^\s+//;
    my @tokens = split(/\s+/, $line);

    return $tokens[2];
}

#for build diff testing
sub files_ignored_by_diff {
    return qw/ build.xml Log /;
}

sub dirs_ignored_by_diff {
    return qw/ logs reports edit_dir /;
}
#TODO - it should test stats.txt and contigs.fa files but this will error since test method
#thinks contigs.fa and supercontigs.fasta are multiple versions of the same file because of the
#way it's grepping for the files .. stats.txt file exists in two places and test method does not
#like that
sub regex_files_for_diff { 
    return qw/ Graph2 LastGraph Log PreGraph Roadmaps Sequences build.xml collated.fastq velvet_asm.afg /;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly/Velvet.pm $
#$Id: Velvet.pm 61146 2010-07-20 21:19:56Z kkyung $
