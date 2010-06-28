package Genome::Model::Tools::Velvet;

use strict;
use warnings;

use POSIX;
use Genome;
use AMOS::AmosLib;
use Data::Dumper;
use Regexp::Common;

class Genome::Model::Tools::Velvet {
    is  => 'Command',
    is_abstract  => 1,
    has_optional => [
        version => {
            is   => 'String',
            doc  => 'velvet version, must be valid velvet version number like 0.7.22, 0.7.30. It takes installed as default.',
            default => 'installed',
        },
    ],
};

sub sub_command_sort_position { 14 }

sub help_brief {
    "Tools to run velvet, a short reads assembler, and work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt velvet ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}


sub resolve_version {
    my $self = shift;

    my ($type) = ref($self) =~ /\:\:(\w+)$/;
    $type = 'velvet'.lc(substr $type, 0, 1);

    my $ver = $self->version;
    $ver = 'velvet_'.$ver unless $ver eq 'installed';
    
    my @uname = POSIX::uname();
    $ver .= '-64' if $uname[4] eq 'x86_64';
    
    my $exec = "/gsc/pkg/bio/velvet/$ver/$type";
    unless (-x $exec) {
        $self->error_message("$exec is not excutable");
        return;
    }

    return $exec;
}

sub get_gap_sizes {
    my $self = shift;
    
    my %gap_sizes;

    unless (-e $self->gap_sizes_file) {
        #file should exist 0 size even if assembly has no scaffolds
        #return blank hash if no gap sizes
        $self->error_message("Can't find gap.txt file: ".$self->gap_sizes_file);
        return;
    }

    my $fh = IO::File->new("<".$self->gap_sizes_file) ||
        die "Can not create file handle to read gap.txt file\n";

    while (my $line = $fh->getline) {
        chomp $line;
        my ($contig_name, $gap_size) = split (/\s+/, $line);
        unless ($contig_name =~ /Contig\d+\.\d+/ and $gap_size =~ /\d+/) {
            $self->error_message("Gap.txt file lines should look like this: Contig4.1 125".
                                 "\n\tbut it looks like this: ".$line);
            return;
        }
        $gap_sizes{$contig_name} = $gap_size;
    }
    $fh->close;

    return \%gap_sizes;
}

sub get_contig_lengths {
    my ($self, $afg_file) = @_;
    my %contig_lengths;
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($afg_file)
        or return;
    while (my $record = getRecord($fh)) {
        my ($rec, $fields, $recs) = parseRecord($record);
        if ($rec eq 'CTG') {
            my $seq = $fields->{seq};
            $seq =~ s/\n//g;

            my ($sctg_num, $ctg_num) = split('-', $fields->{eid});
            my $contig_name = 'Contig'.--$sctg_num.'.'.++$ctg_num;

            $contig_lengths{$contig_name} = length $seq;
        }
    }
    $fh->close;
    return \%contig_lengths;
}

sub contigs_bases_file {
    return $_[0]->directory.'/edit_dir/contigs.bases';
}

sub contigs_quals_file {
    return $_[0]->directory.'/edit_dir/contigs.quals';
}

sub gap_sizes_file {
    return $_[0]->directory.'/edit_dir/gap.txt';
}

sub read_info_file {
    return $_[0]->directory.'/edit_dir/readinfo.txt';
}

sub reads_placed_file {
    return $_[0]->directory.'/edit_dir/reads.placed';
}

sub stats_file {
    return $_[0]->directory.'/edit_dir/stats.txt';
}

sub supercontigs_agp_file {
    return $_[0]->directory.'/edit_dir/supercontigs.agp';
}

sub supercontigs_fasta_file {
    return $_[0]->directory.'/edit_dir/supercontigs.fasta';
}

sub read_names_sqlite {
    return $_[0]->directory.'/velvet_reads.sqlite';
}

1;

