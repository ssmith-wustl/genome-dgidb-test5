package Genome::Model::Tools::Newbler;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use Carp 'confess';

class Genome::Model::Tools::Newbler {
    is => 'Command',
    has => [],
};

sub help_detail {
    return <<EOS
    Tools to work with newbler assembler
EOS
}

sub path_to_version_run_assembly {
    my $self = shift;
    my $assembler = '/gsc/pkg/bio/454/'.$self->version.'/bin/runAssembly';
    unless ( -x $assembler ) {
        $self->error_message( "Invalid version: ".$self->version.' or versions runAssembly is not executable' );
        return;
    }
    return $assembler;
}

#< input fastq files >#
sub input_fastq_files {
    my $self = shift;
    my @files = glob( $self->assembly_directory."/*-input.fastq" );
    unless ( @files ) {
        Carp::confess(
            $self->error_message( "No input fastq files found for assembly")
        ); #shouldn't happen but ..
    }
    return @files;
}

#< newbler output files >#
sub newb_ace_file {
    return $_[0]->assembly_directory.'/consed/edit_dir/454Contigs.ace.1';
}
#TODO - rename these wit newb*
sub scaffolds_agp_file {
    return $_[0]->assembly_directory.'/454Scaffolds.txt';
}

sub all_contigs_fasta_file {
    return $_[0]->assembly_directory.'/454AllContigs.fna';
}

sub all_contigs_qual_file {
    return $_[0]->assembly_directory.'/454AllContigs.qual';
}

#< post assemble output files/dirs >#
sub consed_edit_dir {
    return $_[0]->assembly_directory.'/consed/edit_dir';
}

sub pcap_scaffold_ace_file {
    return $_[0]->consed_edit_dir.'/Pcap.454Contigs.ace';
}

sub contigs_bases_file {
    return $_[0]->consed_edit_dir.'/contigs.bases';
}

sub contigs_quals_file {
    return $_[0]->consed_edit_dir.'/contigs.quals';
}

sub gap_file {
    return $_[0]->consed_edit_dir.'/gap.txt';
}

sub read_info_file {
    return $_[0]->consed_edit_dir.'/readinfo.txt';
}

sub reads_placed_file {
    return $_[0]->consed_edit_dir.'/reads.placed';
}

sub reads_unplaced_file {
    return $_[0]->consed_edit_dir.'/reads.unplaced';
}

sub supercontigs_fasta_file {
    return $_[0]->consed_edit_dir.'/supercontigs.fasta';
}

sub supercontigs_agp_file {
    return $_[0]->consed_edit_dir.'/supercontigs.agp';
}

sub stats_file {
    return $_[0]->consed_edit_dir.'/stats.txt';
}

#< create assembly sub dirs >#
sub create_consed_dir {
    my $self = shift;

    unless ( -d $self->assembly_directory.'/consed' ) {
        Genome::Sys->create_directory( $self->assembly_directory.'/consed' );
    }
    for my $subdir ( qw/ edit_dir phd_dir chromat_dir phdball_dir / ) {
        unless ( -d $self->assembly_directory."/consed/$subdir" ) {
            Genome::Sys->create_directory( $self->assembly_directory."/consed/$subdir" );
        }
    }
    return 1;
}

#< create scaffolds info >#
sub parse_newbler_scaffold_file {
    my $self = shift;

    unless ( $self->scaffolds_agp_file and -s $self->scaffolds_agp_file ) {
        $self->error_message("Need newbler scaffolds file to convert to pcap scaffolds");
        return;
    }

    #create hash of contig info
    my $scaffolds = {};
    my $fh = Genome::Sys->open_file_for_reading( $self->scaffolds_agp_file );
    while ( my $line = $fh->getline ) {
        my @tmp = split( /\s+/, $line );
        #contig describing line
        if ( $tmp[5] =~ /contig\d+/ ) {
            $scaffolds->{$tmp[5]}->{contig_length} = $tmp[7];
            $scaffolds->{$tmp[5]}->{supercontig} = $tmp[0];
            $scaffolds->{$tmp[5]}->{contig_name} = $tmp[5];
            $self->{prev_contig} = $tmp[5];
        }
        #gap describing line .. does not always exist
        if ( $tmp[6] =~ /fragment/ ) { #gap describing line
            my $prev_contig = $self->{prev_contig};
            $scaffolds->{$prev_contig}->{gap_length} = $tmp[5];
        }
    }
    $fh->close;

    #fill in missing gap sizes with default where gap describing line was missing
    my $default_gap_size = ( $self->can('default_gap_size') ) ? $self->default_gap_size : 1;
    for my $contig ( keys %$scaffolds ) {
        $scaffolds->{$contig}->{gap_length} = $default_gap_size
            unless exists $scaffolds->{$contig}->{gap_length};
    }

    #remove contigs less than min_contig_length & update gap size
    for my $contig ( sort keys %$scaffolds ) {
        my $current_scaffold = $scaffolds->{$contig}->{supercontig};
        my $gap_length = $scaffolds->{$contig}->{gap_length};
        my $contig_length = $scaffolds->{$contig}->{contig_length};

        $self->{PREV_SCAFFOLD} = $scaffolds->{$contig} unless defined $self->{PREV_SCAFFOLD};

        if ( $contig_length < $self->min_contig_length ) {
            my $add_to_prev_gap_size = $contig_length + $gap_length;
            $self->{PREV_SCAFFOLD}->{gap_length} += $add_to_prev_gap_size;
            delete $scaffolds->{$contig};            
        }
        else {
            $self->{PREV_SCAFFOLD} = $scaffolds->{$contig};
        }
    }

    #rename remaining contigs to pcap format
    my $pcap_contig = 1;
    my $pcap_supercontig = 0;
    for my $contig ( sort keys %$scaffolds ) {
        my $scaffold_name = $scaffolds->{$contig}->{supercontig};
        $self->{CURR_SCAFFOLD_NAME} = $scaffold_name unless $self->{CURR_SCAFFOLD_NAME};
        if ( not $self->{CURR_SCAFFOLD_NAME} eq $scaffold_name ) {
            $pcap_supercontig++;
            $pcap_contig = 1;
        }
        my $pcap_name = 'Contig'.$pcap_supercontig.'.'.$pcap_contig;
        $scaffolds->{$contig}->{pcap_name} = $pcap_name;
        $pcap_contig++;
        $self->{CURR_SCAFFOLD_NAME} = $scaffold_name;
    }

    #clean up
    delete $self->{CURR_SCAFFOLD_NAME};
    delete $self->{supercontig};
    delete $self->{pcap_name};
    delete $self->{PREV_SCAFFOLD};

    return $scaffolds;
}

1;
