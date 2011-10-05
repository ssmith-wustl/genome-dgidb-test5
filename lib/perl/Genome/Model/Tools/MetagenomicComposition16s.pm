package Genome::Model::Tools::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::MetagenomicComposition16s {
    is => 'Command',
};

sub help_brief {
    'Metagenomic composition 16s tools',
}

sub help_synopsis {
    return <<"EOS"
genome model tools metagenomic-composition-16s
EOS
}

sub version {
    return '2010-07-07';
}

sub path_to_db_files {
    return '/gscmnt/gc4096/info/reference_sequences/chimera-detector-16SrRNA/';
}

sub version_db_nast_file {
    return $_[0]->path_to_db_files.'/'.$_[0]->version.'/rRNA16S.gold.NAST_ALIGNED.fasta';
}

sub version_db_fasta_file {
    return $_[0]->path_to_db_files.'/'.$_[0]->version.'/rRNA16S.gold.fasta';
}

sub path_to_chimera_slayer {
    my $self = shift;

    my $script = '/gsc/pkg/bio/broad/ChimeraSlayer/ChimeraSlayer.pl';
    unless( -x $script ) {
        $self->error_message("Failed to find script or script is not executable: $script");
        return;
    }

    return $script;
}

1;
