package Genome::Model::Tools::Assembly::Ace::ExportContigs;

use strict;
use warnings;

use Genome;
use IO::File;
use Cwd;
use Data::Dumper;

class Genome::Model::Tools::Assembly::Ace::ExportContigs {
    is => 'Genome::Model::Tools::Assembly::Ace',
    has => [
	ace => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'ace file to export contigs from',
	},
	acefile_names => { #TODO remove this
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
	contigs_list => {
	    type => 'Text',
	    doc => 'file of list of contig names to export',
	},
	merge => {
	    type => 'Boolean',
	    is_optional => 1,
	    doc => 'merge exported contigs into a single ace file',
	},
	directory => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'directory where ace files are located',
	},
	ace_out => {
	    type => 'Text',
	    is_optional => 1,
	    doc => 'allow user to define ace file name if input is a single ace',
	},
    ],
};

sub help_brief {
    'Tool to export contig(s) from ace file(s)'
}

sub help_synopsis {
    return <<"EOS"
gmt assembly ace export-contigs --ace Felis_catus-3.0.pcap.ace --contigs-list contigs.txt
gmt assembly ace export-contigs --ace-list acefiles.txt --contigs-list contigs.txt --merge
gmt assembly ace export-contigs --acefile-names file.ace.0,file.ace.2,file.ace.3 --contigs-list contigs.txt --directory /gscmnt/999/assembly/my_assembly --ace-out awollam.exported.ace
EOS
}

sub help_detail {
    return <<EOS
This tool reads in a text file of contig names and creates
a new ace file from those contigs.  If there are multiple
input acefiles, one ace file will be created from contigs
exported from that ace file.  If a single output acefile
is needed, --merge option will merge all exported contigs
together into a single ace file.
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
    
    my $contig_names = {};
    unless (($contig_names) = $self->get_valid_contigs_from_list()) {
	$self->error_message("Failed to validate contigs list");
	return;
    }

    my $new_aces; #array ref
    unless (($new_aces) = $self->filter_ace_files($acefiles, $contig_names, 'export')) {
	$self->error_message("Failed to parse ace files");
	return;
    }

    if ($self->merge) {
	unless ($self->merge_acefiles(acefiles => $new_aces)) {
	    $self->error_message("Failed to merge ace files");
	    return;
	}
    }

    return 1;
}

1;
