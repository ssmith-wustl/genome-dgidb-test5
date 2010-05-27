package Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsAgp;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsAgp {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly build directory',
	},
    ],
};

sub help_brief {
    'Tool to create supercontig agp file';
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

    my $gap_file = $self->directory.'/edit_dir/gap.txt';
    unless ($gap_file) {
	$self->error_message("Can not find file: $gap_file");
	return;
    }

    my $agp_file = $self->directory.'/edit_dir/supercontigs.agp';

    #TODO - need to make create_agp_fa.pl into it's own tool
    my $command = "create_agp_fa.pl -input $bases_file -gapfile $gap_file -agp $agp_file";
    if (system("$command")) {
	$self->error_message("Failed command: $command");
	return;
    }

    return 1;
}

1;
