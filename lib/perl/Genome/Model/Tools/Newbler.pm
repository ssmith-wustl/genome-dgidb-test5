package Genome::Model::Tools::Newbler;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Model::Tools::Newbler {
    is => 'Command',
    has => [],
};

sub help_detail {
    return <<EOS
    Tools to work with newbler assembler
EOS
}

sub path_to_version_run_assembly {
    my $self = shift;
    my $assembler = '/gsc/pkg/bio/454/'.$self->version.'/bin/runAssembly';
    unless ( -x $assembler ) {
        $self->error_message( "Invalid version: ".$self->version.' or versions runAssembly is not executable' );
        return;
    }
    return $assembler;
}

#< input fastq files >#
sub input_fastq_files {
    my $self = shift;
    my @files = glob( $self->assembly_directory."/*-input.fastq" );
    unless ( @files ) {
        Carp::confess(
            $self->error_message( "No input fastq files found for assembly")
        ); #shouldn't happen but ..
    }
    return @files;
}

#< newbler output files >#
sub newb_ace_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/454Contigs.ace.1';
}

sub scaffolds_agp_file {
    return $_[0]->assembly_directory.'/454Scaffolds.txt';
}

#< post assemble output files >#
sub pcap_scaffold_ace_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/Pcap.454Contigs.ace';
}

sub contig_bases_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/contigs.bases';
}

sub contigs_quals_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/contigs.quals';
}

sub gap_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/gap.txt';
}

sub read_info_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/readinfo.txt';
}

sub reads_placed_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/reads.placed';
}

sub reads_unplaced_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/reads.unplaced';
}

sub supercontigs_bases_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/supercontigs.fa';
}

sub supercontigs_agp_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/supercontigs.agp';
}

sub stats_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/stats.txt';
}

1;
