package Genome::Model::Tools::Newbler::ToPcapAce;

use strict;
use warnings;

use Genome;
use Data::Dumper 'Dumper';

class Genome::Model::Tools::Newbler::ToPcapAce {
    is => 'Genome::Model::Tools::Newbler',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Newbler assembly directory',
        },   
    ],
    has_optional => [
        newbler_scaffold_file => {
            is => 'Text',
            doc => 'Scaffolds file created by newbler',
            is_mutable => 1,
        },
        newbler_ace_file => {
            is => 'Text',
            doc => 'Ace file created by newbler',
            is_mutable => 1,
        },
        ace_out => {
            is => 'Text',
            doc => 'Output ace file',
            is_mutable => 1,
        },
        default_gap_size => { #TODO - change to min_contig_length
            is => 'Number',
            doc => 'Gap size to assign to gaps of unknown sizes',
            default => 10,
        },
        min_contig_length => { #TODO .. 
            is => 'Number',
            doc => 'Minimum gap size to include in post assembly process',
            default => 1, #TODO - no default
        },
    ],
};

sub help_brief {
    'Tool to convert newber generated ace file to pcap scaffolded ace file';
}

sub help_detail {
    return <<"EOS"
gmt newbler to-pcap-ace --assembly-directory /gscmnt/111/assembly/newbler_e_coli
gmt newbler to-pcap-ace --assembly-directory /gscmnt/111/assembly/newbler_e_coli --newbler-scaffolds-file assembly-directory /gscmnt/111/assembly/newbler_e_coli/454Scaffolds.txt --newbler-ace-file --assembly-directory /gscmnt/111/assembly/newbler_e_coli/consed/edit_dir/454Contigs.ace --default-gap-size 20
EOS
}

sub execute {
    my $self = shift;

    if ( not $self->_validate_inputs ) {
        $self->error_message( "Failed to validate inputs" );
    }

    if ( $self->newbler_scaffold_file ) {
        #create scaffold pcap format ace file
        my $scaffolds;
        unless ( ($scaffolds) = $self->parse_newbler_scaffold_file ) {
            $self->error_message( "Failed to parse newbler scaffold file" );
            return;
        }

        unless( $self->_write_scaffolded_ace( $scaffolds ) ) {
            $self->error_message( "Failed to write new scaffolded pcap ace file" );
            return;
        }
    } else {
        #create none-scaffolded pcap format ace file
        unless( $self->_write_none_scaffolded_ace ) {
            $self->error_message( "Failed to write new none-scaffolded pcap ace file" );
            return;
        }
    }

    return 1;
}

sub _write_gap_txt_file {
    my ( $self, $scaffolds ) = @_;
    my $gap_file = $self->gap_file;
    unlink $gap_file;
    my $fh = Genome::Sys->open_file_for_writing( $gap_file );
    for my $newb_contig_name ( sort keys %{$scaffolds} ) {
        my $pcap_contig_name = $scaffolds->{$newb_contig_name}->{pcap_name};
        my $gap_size = ( $scaffolds->{$newb_contig_name}->{gap_size} ) ?
            $scaffolds->{$newb_contig_name}->{gap_size} : $self->default_gap_size;
        $fh->print( $pcap_contig_name.' '.$gap_size."\n" );
    }
    $fh->close;

    return 1;
}

sub _validate_inputs {
    my $self = shift;

    #assembly directory
    if ( not -d $self->assembly_directory ) {
        $self->error_message( "Can not find assembly directory: ".$self->assembly_directory );
        return;
    }
    
    #newbler scaffolds file may or may not exist depending
    #on whether assembly is scaffolded or not
    if ( not $self->newbler_scaffold_file ) {
        if ( -s $self->scaffolds_agp_file ) {
            $self->newbler_scaffold_file( $self->scaffolds_agp_file );
        }
    }

    #newbler ace file .. should always exist
    if ( not $self->newbler_ace_file ) {
        $self->newbler_ace_file( $self->newb_ace_file );
    }
    if ( not -s $self->newbler_ace_file ) {
        $self->error_message( "Failed to find newbler ace file or file is zero size: ".$self->newbler_ace_file );
        return;
    }

    #output ace file
    if ( not $self->ace_out ) {
        $self->ace_out( $self->pcap_scaffold_ace_file );
    }

    return 1;
}

sub _write_scaffolded_ace {
    my ( $self, $scaffolds ) = @_;

    $self->status_message( "Found scaffold agp file or file was supplied, generating scaffolded pcap ace file" );

    my $fh = Genome::Sys->open_file_for_reading( $self->newbler_ace_file );
    unlink $self->ace_out.'.int';
    my $fh_int = Genome::Sys->open_file_for_writing( $self->ace_out.'.int' );
    my $print_setting = 0;
    my $contig_count = 0;
    my $read_count = 0;
    while ( my $line = $fh->getline ) {
        if ( $line =~ /^CO\s+/ ) {
            my ( $newb_ctg_name ) = $line =~ /^CO\s+(\S+)/;
            my $rest_of_line = "$'";
            
            if ( exists $scaffolds->{$newb_ctg_name} ) {
                my $pcap_name = $scaffolds->{$newb_ctg_name}->{pcap_name};
                $fh_int->print( "CO $pcap_name $rest_of_line" );
                $contig_count++;
                $print_setting = 1;
                next;
            }
            else {
                $print_setting = 0;
            }
        }
        $fh_int->print( $line ) if $print_setting == 1;
        $read_count++ if $line =~ /^RD\s+/;
    }
    $fh->close;
    $fh_int->close;
    
    #append AS line that describes number of contigs and reads to new ace
    my $as_line =  "AS  $contig_count $read_count\n\n";

    my $fh_out = Genome::Sys->open_file_for_writing( $self->ace_out );
    $fh_out->print( $as_line );
    my $fh_in = Genome::Sys->open_file_for_reading( $self->ace_out.'.int' );
    while ( my $line = $fh_in->getline ) {
        $fh_out->print( $line );
    }
    $fh_out->close;
    $fh_in->close;

    unlink $self->ace_out.'.int';

    return 1;
}

sub _write_none_scaffolded_ace {
    my $self = shift;

    $self->status_message( "Did not find scaffold agp file or file was not supplied, generating unscaffolded pcap ace file" );

    my $fh = Genome::Sys->open_file_for_reading( $self->newbler_ace_file );
    unlink $self->ace_out;
    my $fh_out = Genome::Sys->open_file_for_writing( $self->ace_out );
    my $scaffold_number = 0;
    while ( my $line = $fh->getline ) {
        if ( $line =~ /^CO\s+/ ) {
            my ( $newb_ctg_name ) = $line =~ /^CO\s+(\S+)/;
            my $rest_of_line = "$'";
            my $pcap_name = 'Contig'.$scaffold_number++.'.1';
            $fh_out->print ( "CO $pcap_name $rest_of_line" );
        }
        else {
            $fh_out->print( $line );
        }
    }
    $fh->close;
    $fh_out->close;

    return 1;
}

1;
