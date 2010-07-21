package Genome::Model::Tools::Assembly::CreateOutputFiles::ReadInfo;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Assembly::CreateOutputFiles::ReadInfo {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
	acefile => {
	    is => 'Text',
	    doc => 'Assembly ace file',
	    is_optional => 1,
	    is_mutable => 1,
	},
	output_file => {
	    is => 'Text',
	    doc => 'Output file',
	    is_optional => 1,
	    is_mutable => 1,
	},
    ],
};

sub help_brief {
    'Tool to create assembly readinfo.txt file'
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

    #validate directory
    unless (-s $self->directory) {
	$self->error_message("Failed to find assembly directory: ".$self->directory);
	return;
    }
    #validate ace file
    unless (-s $self->acefile) {
	if (-s $self->directory.'/edit_dir/'.$self->acefile) {
	    $self->acefile($self->directory.'/edit_dir/'.$self->acefile);
	}
	else {
	    $self->error_message("Failed to find ace file: ".$self->acefile.' nor '.
				 $self->directory.'/edit_dir/'.$self->acefile);
	    return;
	}
    }
    #validate output file
    unless ($self->output_file) {
	$self->output_file($self->directory.'/edit_dir/readinfo.txt');
    }
    #parse through ace file line by line
    my $ace_fh = Genome::Utility::FileSystem->open_file_for_reading($self->acefile) ||
	return;
    unlink $self->output_file;
    my $out_fh = Genome::Utility::FileSystem->open_file_for_writing($self->output_file) ||
	return;
    my $info = {};   my $contig_name;
    my %readinfo;
    while (my $line = $ace_fh->getline) {
	chomp $line;
	#get contig name from CO lines
	if ($line =~ /^CO\s+/) {
	    ($contig_name) = $line =~ /^CO\s+(\S+)\s+/;
	}
	#get U_or_C and start position from AF line
	elsif ($line =~ /^AF\s+/) {
	    my @tmp = split (/\s+/, $line);
	    my $read_name = $tmp[1];
	    push @{$readinfo{$read_name}},$tmp[2]; #U_or_C
	    push @{$readinfo{$read_name}}, $tmp[3]; #start position
	}
	#get read length from RD line
	elsif ($line =~ /^RD\s+/) {
	    my @tmp = split (/\s+/, $line);
	    my $read_name = $tmp[1];
	    my $read_length = $tmp[2];
	    my $u_or_c = ${$readinfo{$read_name}}[0];
	    my $start = ${$readinfo{$read_name}}[1];
	    $out_fh->print("$read_name $contig_name $u_or_c $start $read_length\n");
	    #$out_fh->print($tmp[1].' '.$info->{$tmp[1]}->{contig_name}.' '.$info->{$tmp[1]}->{u_or_c}.' '.
		#	$info->{$tmp[1]}->{start_pos}.' '.$tmp[2]."\n");
	    #delete $info->{$tmp[1]};
	    delete $readinfo{$read_name};
	}
	else {
	    next;
	}
    }

    $ace_fh->close;
    $out_fh->close;

    return 1;
}

1;
