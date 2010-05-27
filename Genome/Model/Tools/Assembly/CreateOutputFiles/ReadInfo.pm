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

    my $acefile = ($self->acefile) ? $self->acefile : $self->directory.'/edit_dir/velvet_asm.ace';

    unless (-s $acefile) {
	$self->error_message("Failed to find ace file: $acefile");
	return;
    }

    my $readinfo_file = $self->directory.'/edit_dir/readinfo.txt';

    #PARSING THROUGH ACE FILE LINE BY LINE
    my $in = IO::File->new("< $acefile") ||
	die "Can not create file handle for $acefile";
    my $out = IO::File->new("> $readinfo_file") ||
	die "Can not create file handle for $readinfo_file";
    my $info = {};   my $contig_name;
    while (my $line = $in->getline) {
	chomp $line;
	if ($line =~ /^CO\s+/) {
	    ($contig_name) = $line =~ /^CO\s+(\S+)\s+/;
	}
	elsif ($line =~ /^AF\s+/) {
	    my @tmp = split (/\s+/, $line);
	    #$tmp[1] = read name
	    $info->{$tmp[1]}->{u_or_c} = $tmp[2];
	    $info->{$tmp[1]}->{start_pos} = $tmp[3];
	    $info->{$tmp[1]}->{contig_name} = $contig_name;
	}
	elsif ($line =~ /^RD\s+/) {
	    my @tmp = split (/\s+/, $line);
	    #$tmp[1] = read name
	    #$tmp[2] = read length
	    $out->print($tmp[1].' '.$info->{$tmp[1]}->{contig_name}.' '.$info->{$tmp[1]}->{u_or_c}.' '.
			$info->{$tmp[1]}->{start_pos}.' '.$tmp[2]."\n");
	    delete $info->{$tmp[1]};
	}
	else {
	    next;
	}
    }

    $in->close;
    $out->close;

    return 1;
}

1;
