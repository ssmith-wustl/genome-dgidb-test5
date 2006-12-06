#!/gsc/bin/perl

package GSC::DataSource::Genbank;
use base "GSC::DataSource";

use strict;
use warnings;
use GSCApp;



use App::Object::Class;
App::Object::Class->create (
			    class_name 	  => __PACKAGE__,
			    type_name 	  => __PACKAGE__,
			    source_name   => 'Genbank',
			    inheritance   => [qw/GSC::DataSource/]
			   ) 
or die ("Failed to make class metadata for " . __PACKAGE__);

GSC::DataSource::Genbank->create(
				 data_source_id  => 2,
				 source_name 	 => 'Genbank',
				 source_revision => 'build35_11_2005'
				);


sub release {
    return 'build35_11_2005';
}

sub genbank_info {
    my $class = shift;
    my %args = @_;

    my $asn_index_file = qq{/gscmnt/temp209/info/medseq/entrez_gene/build35/Homo_sapiens.idx};
    my $inx = Bio::ASN1::EntrezGene::Indexer->new( -filename => $asn_index_file ); 
    return $inx->fetch_hash($args{locus_id});
}

sub get_chromosome_name {
    my $class = shift;
    my %args = @_;
    my $genbank_info = $args{genbank_info};
    
    my @something = grep { $_->{subtype} eq 'chromosome' } @{ $genbank_info->[0]->{source}->[0]->{subtype} };
    my $chr_name = $something[0]->{name};

    unless (defined $chr_name) {
	Carp::confess("Could not find chromosome name in magic genbank hash!");
    }
    return $chr_name;
}


sub get_locus_name {
    my $class = shift;
    my %args = @_;
    my $genbank_info = $args{genbank_info};

    my $locus_name;
    if ( exists( $genbank_info->[0]->{properties}->[0]->{properties} ) ) {
	my @props = @{ $genbank_info->[0]->{properties}->[0]->{properties} };
	
        @props =  grep { $_->{label} eq 'Official Symbol' } @props;
	$locus_name = $props[0]->{text};
    }
    elsif ( exists $genbank_info->[0]->{gene}->[0]->{syn} ) {
	my @syns = @{ $genbank_info->[0]->{gene}->[0]->{syn} };
        $locus_name = $syns[0];	
    }
    else {
	Carp::confess("Could not find locus name in Genbank magic hash!");
    }

    return $locus_name;
}


sub get_slice_boundary {
    my $class = shift;
    my %args = @_;
    my $gene        = $args{gene};
    my @transcripts = @{$args{transcripts}};

    my ($gb5_boundary, $gb3_boundary);
    foreach my $t (@transcripts) {
	my @exons = GSC::Sequence::Tag::Exon->get_from_genbank(transcript => $t);

	my $start = $exons[0]->{from}; 
	my $end   = $exons[-1]->{to};
        if (!defined($gb5_boundary) || $start < $gb5_boundary) {
            $gb5_boundary = $start;
        }
        if (!defined($gb3_boundary) || $end > $gb3_boundary) {
            $gb3_boundary = $end;
        }
    }

    my $slice_start = $gene->start();
    my $slice_end = $gene->end();
    
    ## Adjust slice boundary to accomodate Martian GenBank Exons
    if ($gb5_boundary < $slice_start) {  $slice_start = $gb5_boundary;  }
    if ($gb3_boundary > $slice_end)   {  $slice_end   = $gb3_boundary;  }
    
    $slice_start -= 50000;
    $slice_end   += 50000;
    
    while ( $slice_start !~ /001$/ ) {
	$slice_start--;
    }
    while ( $slice_end !~ /999$/ ) {
	$slice_end++;
    }

    return ($slice_start, $slice_end);
}


sub create_tags_for_locus_id {
    my $self = shift;
    my %args = $self->init_args(@_);

    my %tag_relationship = ();
    $args{tag_rel} = \%tag_relationship;


    foreach my $type (@{$args{tag_types}}) {
	my $class = "GSC::Sequence::Tag::" . $type;
	$class->add_genbank(%args);
    }
=cut

    GSC::Sequence::Tag::Transcript->add_genbank(%args) or return;   # writes %tag_relationship
    GSC::Sequence::Tag::Exon->add_genbank(%args)       or return;   # reads  %tag_relationship
    GSC::Sequence::Tag::CDS->add_genbank(%args)        or return;   # reads  %tag_relationship
    GSC::Sequence::Tag::UTR->add_genbank(%args)        or return;   # reads  %tag_relationship    
=cut
    return 1;
}


1;
