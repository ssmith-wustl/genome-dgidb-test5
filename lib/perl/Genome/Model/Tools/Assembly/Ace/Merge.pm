package Genome::Model::Tools::Assembly::Ace::Merge;

use strict;
use warnings;

use Genome;
use IO::File;
use Cwd;
use Data::Dumper;

class Genome::Model::Tools::Assembly::Ace::Merge {
    is => 'Genome::Model::Tools::Assembly::Ace',
    has => [
	ace => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'ace file to merge',
	},
	acefile_names => {
	    type => 'Text',
	    is_optional => 1,
	    is_many => 1,
	    doc => 'comma separated string of ace file names',
	},
	ace_list => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'file of list of ace files to export contigs from',
	},
	directory => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'directory where ace files are located',
	},
    ],
};

sub help_brief {
    'Tool to export contig(s) from ace file(s)'
}

sub help_detail {
    return <<"EOS"
gmt assembly ace merge --ace Felis_catus-3.0.pcap.ace
gmt assembly ace merge --ace-list acefiles.txt  --directory /gscmnt/999/assembly/my_assembly
gmt assembly ace merge --acefile-names file.ace.0,file.ace.2,file.ace.3
EOS
}

sub execute {
    my $self = shift;

    $self->directory(cwd()) unless $self->directory;

    my $acefiles; #array ref
    unless (($acefiles) = $self->get_valid_input_acefiles()) {
	$self->error_message("Failed to validate ace input(s)");
	return;
    }

    unless ($self->merge_acefiles($acefiles)) {
	$self->error_message("Failed to merge ace files");
	return;
    }
    return 1;
}

1;
