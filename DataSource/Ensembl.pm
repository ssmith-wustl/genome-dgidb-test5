#!/gsc/bin/perl

package GSC::DataSource::Ensembl;
use base "GSC::DataSource";

use lib '/gsc/scripts/share/ensembl-36/ensembl/modules';
use lib '/gsc/scripts/share/ensembl-36/ensembl-external/modules';
use lib '/gsc/scripts/share/ensembl-36/ensembl-variation/modules';

use strict;
use warnings;
use GSCApp;

## Set up Ensembl database connections
my $dba = new Bio::EnsEMBL::DBSQL::DBAdaptor( -host   => host(),
					      -user   => user(),
					      -dbname => dbname() );    

my $vdba = new Bio::EnsEMBL::Variation::DBSQL::DBAdaptor( -host   => host(),
							  -user   => user(),
							  -dbname => variation_dbname() );  


use App::Object::Class;
App::Object::Class->create (
			    class_name 	  => __PACKAGE__,
			    type_name 	  => __PACKAGE__,
			    source_name   => 'Ensembl',
			    inheritance   => [qw/GSC::DataSource/]
			   ) 
or die ("Failed to make class metadata for " . __PACKAGE__);

GSC::DataSource::Ensembl->create(
				 data_source_id  => 1,
				 source_name 	 => 'Ensembl',
				 source_revision => '36_35i'
				);

sub release {
    my $self = shift;
    if (ref($self)) { return $self->{source_revision}; }
    else { return '36_35i'; }
}

sub genbank_revision {
    
    my ($self) = shift;

=cut
    (my $gb_revision = $self->{source_revision} ) =~ /^\d+\_(\d+)$/;
    
    my $gb_source = GSC::DataSource->get(source_name 	 => 'Genbank',
                                         source_revision => $gb_revision);
 
    $self->warning('no Genbank data source available') unless ($gb_source);
    
    return $gb_revision;
=cut

    
}

sub host {
    return 'ensembldb.ensembl.org';
}

sub user {
    return 'anonymous';
}

sub dbname {
    return join '_', 'homo_sapiens_core', release();
}

sub variation_dbname {
    return join '_', 'homo_sapiens_variation', release();
}

sub slice_adaptor {
    return $dba->get_SliceAdaptor();
}


sub fetch_gene {
    my $self = shift;
    my %args = @_;

    my $chr_name        = $args{chr_name};
    my $locus_name      = $args{locus_name};
    my $locus_id 	= $args{locus_id};
    my @transcripts     = @{$args{transcripts}};

    my $gene_adaptor    = $dba->get_GeneAdaptor();
    my $padded_locus_id = GSC::Gene->padded_locus_link_id(locus_link_id =>$args{locus_id});

    my @genes = ( );

    # try a bunch of different ways of fetching the gene until something hits paydirt
    foreach ( (map {$_->{accession}} @transcripts), $padded_locus_id, $locus_id, $locus_name) {	
	push @genes, @{ $gene_adaptor->fetch_all_by_external_name($_) };
	last if @genes;
    }

    # try another way
    unless ( @genes ) {
        my $ref = $gene_adaptor->fetch_by_display_label($locus_name);
        if ( defined($ref) && ( ref($ref) eq 'ARRAY' ) ) {
            push @genes, @{$ref};
        }
    }
    
    # and some more ways! (too bad ensembl doesn't make this a little easier...)
    unless ( @genes ) {
        my $bogus = $locus_id;
        while ( length($bogus) < 7 ) {
            $bogus = '0' . $bogus;
            push @genes, @{ $gene_adaptor->fetch_all_by_external_name($bogus) };
	    last if @genes;
        }
    }
    
    @genes = grep { $_->slice->seq_region_name() eq $chr_name } @genes;
    if ( @genes > 1 ) { @genes = grep { $_->external_name eq $locus_name } @genes; }
    if ( @genes > 1 ) { Carp::confess("Retrieved more than 1 gene from Ensembl!"); }
    
    my $gene = $genes[0];
}


sub create_tags_for_locus_id {
    
    my $self = shift;
    my %args = $self->init_args(@_);

    my %tag_relationship = ();
    $args{tag_rel} = \%tag_relationship;


    foreach my $type (@{$args{tag_types}}) {
	my $class = "GSC::Sequence::Tag::" . $type;
	$class->add_ensembl(%args);
    }
=cut

    GSC::Sequence::Tag::Transcript->add_ensembl(%args)     or return;  # writes %tag_relationship    
    GSC::Sequence::Tag::ProteinFeature->add_ensembl(%args) or return;  # reads  %tag_relationship
    GSC::Sequence::Tag::Exon->add_ensembl(%args)           or return;  # reads  %tag_relationship    
    GSC::Sequence::Tag::CDS->add_ensembl(%args)            or return;  # reads  %tag_relationship
    GSC::Sequence::Tag::UTR->add_ensembl(%args)            or return;  # reads  %tag_relationship

    GSC::Sequence::Tag::Repeat->add_ensembl(%args)         or return;  # doesn't use %tag_relationship  
    GSC::Sequence::Tag::Variation->add_ensembl(%args)      or return;  # doesn't use %tag_relationship   
=cut
    return 1;
}

1;
