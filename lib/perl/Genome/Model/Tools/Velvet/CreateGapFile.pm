package Genome::Model::Tools::Velvet::CreateGapFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use Data::Dumper 'Dumper';


class Genome::Model::Tools::Velvet::CreateGapFile {
    is => 'Genome::Model::Tools::Velvet',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Assembly build directory',
        },
        min_contig_length => {
            is => 'Number',
            doc => 'Minimum contig length to process',
        }
    ],
};

sub help_brief {
    'Tool to create gap.txt file from velvet created contigs.fa file';
}

sub help_detail {
    return <<EOS
gmt velvet create-gap-file --assembly-directory /gscmnt/111/assembly/e_coli_velvet_assembly --min-contig-length 200
EOS
}

sub execute {
    my $self = shift;

    unless ( $self->create_edit_dir ) {
	$self->error_message("assembly edit_dir does not exist and could not create one");
	return;
    }

    my $scaf_info;
    unless( $scaf_info = $self->get_scaffold_info_from_afg_file ) {
        $self->error_message( "Failed to get scaf info from afg file" );
        return;
    }

    unlink $self->gap_sizes_file;
    my $fh = Genome::Sys->open_file_for_writing( $self->gap_sizes_file );
    
    for my $contig ( sort {$a<=>$b} keys %$scaf_info ) {
        my ( $supercontig, $contig ) = $contig =~ /(\d+)\.(\d+)/;
        my $next_contig_number = $contig + 1;
        my $next_contig_in_scaf = $supercontig.'.'.$next_contig_number;

        if ( exists $scaf_info->{$next_contig_in_scaf} ) {
            my $pcap_name = 'Contig'.--$supercontig.'.'.++$contig;
            $fh->print( "$pcap_name 20\n" ); #default gap size for unknown gaps
        }
    }

    $fh->close;
    return 1;
}

#not used by maybe used when/if contigs.fa file reports reliable gap info
sub gap_sizes_from_contigs_fa_file {
    my $self = shift;
    
    unlink $self->gap_sizes_file;
    my $fh = Genome::Sys->open_file_for_writing($self->gap_sizes_file);

    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $self->velvet_contigs_fa_file );

    my $supercontig_number = 0;
    my %gap_sizes;
    while (my $seq = $io->next_seq) {
        #remove lead/tail-ing Ns .. shouldn't be any but could be bad if there
        $seq =~ s/^N+//;
        $seq =~ s/N+$//;
        #skip if less than min length
        next unless length $seq->seq >= $self->min_contig_length;
        #split into array of bases and gaps
	my @bases = split (/N+/i, $seq->seq);
	my @gaps = split (/[ACGT]+/i, $seq->seq);
        #remove undefined first @gaps element
        shift @gaps;

	my $contig_number = 0;
        my $is_leading_contig = 1;
        my $contig_name;
        my $significant_contig_exists = 0;

        for my $i ( 0 .. $#bases ) {
            $significant_contig_exists = 1 if length $bases[$i] >= $self->min_contig_length;

            next if $is_leading_contig and length $bases[$i] < $self->min_contig_length;
            next if not $gaps[$i]; #no gap info for last contig in scaffold
            next if $i == $#bases; #no gap info for last contig in scaffold

            if ( length $bases[$i] >= $self->min_contig_length ) {
                $contig_name = $supercontig_number.'.'.++$contig_number;
                $gap_sizes{$contig_name} += length $gaps[$i];
                $is_leading_contig = 0;
                $significant_contig_exists = 1;
            }
            else {
                $gap_sizes{$contig_name} += length $bases[$i];
                $gap_sizes{$contig_name} += length $gaps[$i];
            }
        }
        $supercontig_number++ if $significant_contig_exists == 1;
    }
    #write gap file
    for my $contig ( sort {$a<=>$b} keys %gap_sizes ) {
        $fh->print( 'Contig'.$contig.' '.$gap_sizes{$contig}."\n" );
    }

    $fh->close;
    return 1;
}

1;
