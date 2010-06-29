package Genome::Model::Tools::Assembly::GetCloneReads;

use strict;
use warnings;

use Genome;
use IO::File;
use Cwd;


class Genome::Model::Tools::Assembly::GetCloneReads {
    is => 'Command',
    has => [
	clone => {
	    is => 'Text',
	    doc => 'Clone name to get reads for',
	    is_optional => 1,
	},
	list_of_clones => {
	    is => 'Text',
	    doc => 'List of clones names to get read for',
	    is_optional => 1,
	},
	read_type => {
	    is => 'Text',
	    doc => 'Read types to get',
	    valid_values => ['all', 'end'],
	},
	output_dir => {
	    is => 'Text',
	    doc => 'Directory to output data to',
	    is_mutable => 1,
	    is_optional => 1,
	}
    ],
};

sub help_brief {
    'Tool to dump reads for finishing clones'
}

sub help_synopsis {
    return <<"EOS"
gmt assembly get-clone-reads --list-of-clones /gscmnt/111/my_assembly/list --read-type end --output-dir /gscmnt/111/my_assembly
gmt assembly get-clone-reads --clone H_GY-34H03 --read-type all
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my @clones;
    unless (@clones = $self->_get_clones()) {
	$self->warning_message("Failed to get clones names to dump");
	return;
    }

    foreach my $clone_name (@clones) {
	$self->status_message("Getting reads for clone: $clone_name\n");
	
	my $co = GSC::Clone->get(clone_name => $clone_name);
	unless ($co) {
	    $self->status_message("Failed to get GSC::Clone object for $clone_name .. skipping");
	    next;
	}
	#get clone id
	my $id;
	unless ($id = $self->_get_id($co)) {
	    $self->status_message("Failed get get id .. skipping");
	    next;
	}

	#get reads
	my $reads;
	unless ($reads = $self->_get_reads($id)) {
	    $self->status_message("Failed to get any reads .. skipping");
	    next;
	}

	$self->status_message("Found ".scalar @$reads." reads to dump");

	#print re_ids to file
	unless ($self->_write_read_ids_to_file($clone_name, $reads)) {
	    $self->error_message("Failed to write read ids to file $clone_name.re_ids");
	    return;
	}

	#dump fasta/quals
	unless ($self->_dump_data($clone_name)) {
	    $self->error_message("Failed to dump fasta/qual");
	    return;
	}
    }

    return 1;
}

sub _get_id { #not sure what id this is .. 
    my ($self, $co) = @_;
    #TODO - this seems to never be defined
    my $dna_ext_name = GSC::DNAExternalName->get (
	name_type => 'ncbi clone id',
	dna_id => $co->id,
	);
    my $id;
    if ($dna_ext_name) {
	$id = $dna_ext_name->name;
    }
    else {
	$id = $co->convert_name(output => 'agi');
	if (! $id) {
	    $id = $co->convert_name(output => 'ncbi');
	}
    }
    return $id;
}

sub _get_reads {
    my ($self, $id) = @_;

    my @reads;
    if ($self->read_type eq 'all') {
	@reads = GSC::Sequence::Read->get(
	    clone_id => $id,
	    );
    }
    else {
	@reads = GSC::Sequence::Read->get(
	    clone_id => $id,
	    trace_type_code => 'CLONEEND',
	    );
    }
    
    return \@reads;
}

sub _write_read_ids_to_file {
    my ($self, $clone_name, $re_ids) = @_;

    $self->output_dir(cwd()) unless $self->output_dir;

    unlink $self->output_dir.'/'.$clone_name.'.re_ids';
    my $fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_dir.'/'.$clone_name.'.re_ids') ||
	return;
    $fh->print(map {$_->seq_id."\n"} @$re_ids);
    $fh->close;
    unless (-s $self->output_dir.'/'.$clone_name.'.re_ids') {
	$self->error_message("Failed to write $clone_name.re_ids file or file is blank");
	return;
    }
    return 1;
}

sub _dump_data {
    my ($self, $clone_name) = @_;

    my $re_ids_file = $self->output_dir.'/'.$clone_name.'.re_ids';
    my $fasta_out = $self->output_dir.'/'.$clone_name.'.fasta';
    my $qual_out = $self->output_dir.'/'.$clone_name.'.qual';

    unlink $fasta_out, $qual_out;
    $self->status_message("Dumping fasta\n");
    if (system("seq_dump --input-file $re_ids_file --output type=fasta,file=$fasta_out,maskq=1,maskv=1,nocvl=35")) {
	$self->error_message("Failed to dump fasta for $clone_name");
	return;
    }
    $self->status_message("Dumping quality\n");
    if (system ("seq_dump --input-file $re_ids_file --output type=qual,file=$qual_out")) {
	$self->error_message("Failed to dump qual for $clone_name");
	return;
    }

    return 1;
}

sub _get_clones {
    my $self = shift;
    my @clones;

    if ($self->list_of_clones) {
	#unless -s $self->list_of_clones ....
	my $fh = Genome::Utility::FileSystem->open_file_for_reading($self->list_of_clones) ||
	    return;
	while (my $line = $fh->getline) {
	    next if $line =~ /^\s+$/;
	    chomp $line;
	    unless (grep(/^$line$/, @clones)) {
		push @clones, $line;
	    }
	}
	$fh->close;
    }
    push @clones, $self->clone if $self->clone;

    return @clones;
}

1;
