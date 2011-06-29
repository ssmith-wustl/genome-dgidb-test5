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
        default_gap_size => {
            is => 'Number',
            doc => 'Gap size to assign to gaps of unknown sizes',
            default => 10,
        },
    ],
};

sub help_brief {
}

sub help_detail {
    return <<"EOS"
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
        unless ( ($scaffolds) = $self->_parse_newbler_scaffold_file ) {
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

sub _parse_newbler_scaffold_file {
    my $self = shift;

    my $scaffolds = {};

    my $fh = Genome::Sys->open_file_for_reading( $self->newbler_scaffold_file );

    my $pcap_contig = 1;
    my $pcap_supercontig = 0;

    my $newb_contig;
    my $newb_supercontig;

    while ( my $line = $fh->getline ) {
        my @tmp = split( /\s+/, $line );
        $newb_supercontig = $tmp[0];
        $self->{current_scaffold} = $newb_supercontig unless defined $self->{current_scaffold};
        #contig describing line
        if ( $tmp[5] =~ /contig\d+/ ) { # and prev line was contig desc write default gap
            my $newb_contig_name = $tmp[5];
            if ( not $self->{current_scaffold} eq $newb_supercontig ) {
                #reached next scaffold in agp file increment supercontig number, reset contig number to 1
                $pcap_supercontig++;
                $pcap_contig = 1;
                $self->{current_scaffold} = $newb_supercontig;
            }
            $scaffolds->{$newb_contig_name}->{pcap_name} = 'Contig'.$pcap_supercontig.'.'.$pcap_contig;
            $pcap_contig++;
            #newbler scaffold agp file does not report gaps less than 20 so need to make it up
            #will have 2 contig desc lines in a row rather than alternating contigs and frags
            if ( defined $self->{prev_line_desc} and $self->{prev_line_desc} eq 'contig' ) {
                #set default gap size
                my $prev_pcap_contig_name = $self->{prev_newb_contig_name};
                $scaffolds->{$prev_pcap_contig_name}->{gap_size} = $self->default_gap_size;
            }
            $self->{prev_newb_contig_name} = $newb_contig_name;
            $self->{prev_line_desc} = 'contig';
        }
        #gap size defining line followed by contig describing line but not always there
        if ( $tmp[6] =~ /fragment/i ) { #and prev line was contig write gap described here
            my $gap_size = $tmp[5];
            my $prev_newb_contig = $self->{prev_newb_contig_name};
            $scaffolds->{$prev_newb_contig}->{gap_size} = $gap_size;
            $self->{prev_line_desc} = 'fragment';
        }
    }

    $fh->close;

    return $scaffolds;
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
    unlink $self->ace_out;
    my $fh_out = Genome::Sys->open_file_for_writing( $self->ace_out );
    while ( my $line = $fh->getline ) {
        if ( $line =~ /^CO\s+/ ) {
            my ( $newb_ctg_name ) = $line =~ /^CO\s+(\S+)/;
            my $rest_of_line = "$'";

            my $pcap_name = $scaffolds->{$newb_ctg_name}->{pcap_name};
            unless ( $pcap_name ) {
                $self->error_message( "Failed to get pcap name for newbler contig: $newb_ctg_name" );
                return;
            }
            $fh_out->print( "CO $pcap_name $rest_of_line" );
        }
        else {
            $fh_out->print( $line );
        }
    }
    $fh->close;
    $fh_out->close;
    
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
