package Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsFasta;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsFasta {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to create supercontigs fasta file';
}

sub help_synopsis {
    my $self = shift;
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $bases_file = $self->directory.'/edit_dir/contigs.bases';
    unless (-s $bases_file) {
	$self->error_message("Can not find file: $bases_file");
	return;
    }
    
    my $agp_file = $self->directory.'/edit_dir/supercontigs.agp';
    unless (-s $agp_file) {
	$self->error_message("Failed to find file: $agp_file");
	return;
    }

    my $command = "xdformat -n -I $bases_file";

    if (system ("$command")) {
	$self->error_message("Failed to create blastdb of contigs.bases using command:\n\t$command");
	return;
    }

    my $supercontigs_fasta = $self->directory.'/edit_dir/supercontigs.fasta';

    #TODO - should make a tool out of create_fa_file_from_agp.pl .. old syang's script
    my $cmd = "create_fa_file_from_agp.pl $agp_file $supercontigs_fasta $bases_file";
    if (system("$cmd")) {
	$self->error_message("Failed to create supercontigs.fasta file using command\n\t$cmd");
	return;
    }

    #remove blast db files
    unlink $self->directory.'/edit_dir/contigs.bases.xni';
    unlink $self->directory.'/edit_dir/contigs.bases.xns';
    unlink $self->directory.'/edit_dir/contigs.bases.xnd';
    unlink $self->directory.'/edit_dir/contigs.bases.xnt';

    return 1;
}

1;
