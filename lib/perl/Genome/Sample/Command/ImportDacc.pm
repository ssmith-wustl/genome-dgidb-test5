package Genome::Sample::Command::ImportDacc;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require XML::LibXML;

class Genome::Sample::Command::ImportDacc {
    is  => 'Command',
    has => [
        sra_sample_id => {
            is => 'Text',
            is_input => 1,
            shell_args_position => 1,
            doc => 'SRA id to download and import from the DACC.',
        },
        xml_files => {
            is => 'Text',
            is_many => 1,
            shell_args_position => 2,
            doc => 'XML files',
        },
    ],
};

sub execute {
    my $self = shift;

    $self->status_message('Update individual, sample and library...');
    my $sample_info = $self->_sample_info_from_xmls;
    return if not $sample_info;

    my $taxon = Genome::Taxon->get(name => $sample_info->{scientific_name});
    if ( not defined $taxon ) {
        $self->error_message('Cannot get taxon for name: '.$sample_info->{scientific_name});
        return;
    }
    $self->status_message('Taxon: '.join(' ', map { $taxon->$_ } (qw/ id name /)));

    $self->status_message('Update individual...');
    if ( not defined $sample_info->{gap_subject_id} ) {
        $self->error_message('No gap subject id for SRA id: '.$self->sra_sample_id);
        return;
    }
    my $individual_name = 'GAP-'.$sample_info->{gap_subject_id};
    my %individual_attrs = (
        taxon_id => $taxon->id,
        upn => $sample_info->{gap_subject_id},
        gender => $sample_info->{sex},
        description => 'Imported from the DACC. Individual name format is GAP-$GAP_ACCESSION',
    );
    my $individual = Genome::Individual->get(name => $individual_name);
    if ( not defined $individual ) {
        $individual = Genome::Individual->create(
            name => $individual_name,
            %individual_attrs,
        );
        if ( not defined $individual ) {
            $self->error_message('Cannot create individual for name: '.$individual_name);
            return;
        }
        unless ( UR::Context->commit ) {
            $self->error_message('Cannot commit new individual to DB');
            return;
        }
    }
    else {
        for my $attr ( keys %individual_attrs ) {
            $individual->$attr( $individual_attrs{$attr} );
        }
    }
    $self->status_message('Individual: '.join(' ', map { $individual->$_ } (qw/ id name /)));
    
    $self->status_message('Update sample...');
    my $tissue = GSC::Tissue->get( $sample_info->{body_site} );
    if ( not $tissue ) {
        $tissue = GSC::Tissue->create( $sample_info->{body_site} );
        if ( not defined $tissue ) {
            $self->error_message('Cannot create tissue: '.$sample_info->{body_site});
            return;
        }
        unless ( UR::Context->commit ) {
            $self->error_message('Cannot commit tissue to DB');
            return;
        }
    }
    $self->status_message('Tissue: '.$tissue->tissue_name);

    my $sample_name = $sample_info->{sra_sample_id};
    my %sample_attrs = (
        taxon_id => $taxon->id,
        source_id => $individual->id,
        source_type => $individual->subject_type,
        tissue_label => $sample_info->{sample_type}, 
        tissue_desc => $sample_info->{body_site}, 
        extraction_label => $sample_info->{sra_sample_id},
        extraction_type => 'genomic',
        extraction_desc => $sample_info->{description}, 
        cell_type => 'unknown',
        _nomenclature => 'unknown',
    );
    my $sample = Genome::Sample->get(name => $sample_name);
    if ( not $sample ) {
        $sample = Genome::Sample->create(
            name => $sample_name,
            %sample_attrs,
        );
        if ( not defined $sample ) {
            $self->error_message('Cannot create sample ofr name: '.$sample_info->{sra_sample_id});
            return;
        }
        unless ( UR::Context->commit ) {
            $self->error_message('Cannot commit new sample');
            return;
        }
    }
    else {
        for my $attr ( keys %sample_attrs ) {
            $sample->$attr( $sample_attrs{$attr} );
        }
        if ( not UR::Context->commit ) {
            $self->error_message('Cannot commit updates to sample');
            return;
        }
    }
    $self->status_message('Sample: '.join(' ', map { $sample->$_ } (qw/ id name /)));

    my $library;
    my @libraries = $sample->libraries;
    if ( not @libraries ) {
        Genome::Library->create(
            sample_id => $sample->id,
            name => $sample->name.'-extlibs'
        );
        my ($library) = $sample->libraries;
        if ( not $library ) {
            $self->error_message('Cannot create library for sample: '.$sample->name);
            return;
        }
        if ( not UR::Context->commit ) {
            $self->error_message('Cannot commit new library');
            return;
        }
    }
    else {
        $library = $libraries[$#libraries];
        $library->name( $sample->name.'-extlibs' );
    }
    $self->status_message('Library: '.join(' ', map { $library->$_ } (qw/ id name /)));

    $self->status_message('Update individual, sample and library...');

    return 1;
}

sub _sample_info_from_xmls {
    my $self = shift;

    $self->status_message('Sample info from XMLs...');

    # Get library from XMLs
    my @xml_files = $self->xml_files;
    if ( not @xml_files ) {
        $self->error_message('No XML files!');
        return;
    }

    my $libxml = XML::LibXML->new();
    my @sample_infos;
    for my $xml_file ( @xml_files ) {
        next if not -s $xml_file; # seen files w/ 0 size
        my $xml = eval { $libxml->parse_file($xml_file); };
        if ( not defined $xml ) {
            $self->error_message("Could not parse report XML from file ($xml_file): $@");
            return;
        }

        my %sample_info;

        # sample
        my ($sample_node) = grep { $_->nodeType == 1 } $xml->findnodes('RunViewer/SAMPLE');
        if ( not defined $sample_node ) {
            next; # ok...we'll try the next one
        }
        $sample_info{sra_sample_id} = $sample_node->getAttribute('accession');
        if ( not defined $sample_info{sra_sample_id} ) {
            $self->error_message('No sra sample id found in sample node in XML file: '.$xml_file);
            return;
        }
        for my $attr (qw/ description /) { 
            my ($node) = grep { $_->nodeType == 1 } $sample_node->findnodes(uc($attr));
            if ( not defined $node ) {
                $self->error_message("No library attribute ($attr) node found in XML file: $xml_file");
                return;
            }
            my ($value) = $node->to_literal;
            if ( not defined $value ) {
                $self->error_message("Got sample attribute ($attr) node, but there was not a value in it");
                return;
            }
            $sample_info{$attr} = $node->to_literal;
        }

        # sample name
        for my $attr (qw/ scientific_name /) {
            my ($node) = grep { $_->nodeType == 1 } $sample_node->findnodes('SAMPLE_NAME/'.uc($attr));
            if ( not defined $node ) {
                $self->error_message('No sample name node found for '.$attr.' in XML file: '.$xml_file);
                return;
            }
            $sample_info{ lc $node->nodeName } = $node->to_literal;
        }

        # sample attrs
        my @sample_attr_nodes = grep { $_->nodeType == 1 } $sample_node->findnodes('SAMPLE_ATTRIBUTES/*');
        if ( not @sample_attr_nodes ) {
            $self->error_message('No sample attribute nodes found in XML file: '.$xml_file);
            return;
        }
        for my $node ( @sample_attr_nodes ) {
            my ($tag_node) = $node->findnodes('TAG');
            my $attr = $tag_node->to_literal;
            #next if not grep { $attr eq $_ } @sample_attrs_in_attrs;
            my ($value_node) = $node->findnodes('VALUE');
            $sample_info{ $tag_node->to_literal } = $value_node->to_literal;
        }

        push @sample_infos, \%sample_info;
    }

    if ( not @sample_infos ) {
        $self->error_message("No sample info in XMLs");
        return;
    }

    $self->status_message('Validating sample info');

    my $main_sample_info = $sample_infos[0];
    for my $sample_info ( @sample_infos[1..$#sample_infos] ) {
        for my $attr ( keys %$sample_info ) {
            if ( not defined $main_sample_info->{$attr} ) {
                # some of these are have incorrect keys
                $main_sample_info->{$attr} = $sample_info->{$attr};
            }
            elsif ( $main_sample_info->{$attr} ne $sample_info->{$attr} ) {
                $self->error_message("Mismatching data from sample infos for $attr: '$main_sample_info->{$attr}' VS '$sample_info->{$attr}");
                print Dumper(@sample_infos);
                return;
            }
        }
    }

    $self->status_message('Sample info from XMLs...OK');

    return $main_sample_info;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

