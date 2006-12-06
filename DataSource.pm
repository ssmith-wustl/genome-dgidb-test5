#!/gsc/bin/perl

package GSC::DataSource;

use strict;
use warnings;
use GSCApp;


use App::Object::Class;
App::Object::Class->create (
			    class_name 	  => __PACKAGE__,
			    type_name 	  => __PACKAGE__,
			    properties    => [qw/
						 data_source_id
						 source_name
						 source_revision
						 /],
			    id_properties => ['data_source_id'],
			   ) 
    or die ("Failed to make class metadata for " . __PACKAGE__);

require GSC::DataSource::Ensembl;

=cut
sub get {

    my $class = shift;
    my %params = @_;

    $class .= "::" . delete $params{source_name};
    return $class->new(%params);
}
=cut

sub init_args {
    my $class = shift;
    my %args = @_;

    # get the chromosome number and locus name from the giant hash of genbank info
    $args{genbank_info} = GSC::DataSource::Genbank->genbank_info(locus_id => $args{locus_id});
    my $chr_name = GSC::DataSource::Genbank->get_chromosome_name(genbank_info => $args{genbank_info});
    $args{locus_name} = GSC::DataSource::Genbank->get_locus_name(genbank_info => $args{genbank_info});
    $args{chromosome} = GSC::Sequence::Chromosome->get('sequence_item_name' => "NCBI-human-build35-chrom".lc($chr_name));

    my @transcripts = GSC::Sequence::Tag::Transcript->get_from_genbank(genbank_info => $args{genbank_info});  
    $args{gene} = GSC::DataSource::Ensembl->fetch_gene(
						       chr_name    => $chr_name,
						       locus_name  => $args{locus_name},
						       locus_id    => $args{locus_id},
						       transcripts => \@transcripts
						      );  

    # Determine the slice boundaries and get the gene sequence object    
    ($args{slice_start}, $args{slice_end}) =
	GSC::DataSource::Genbank->get_slice_boundary( gene        => $args{gene}, 
						      transcripts => \@transcripts );
    $args{slice} = GSC::DataSource::Ensembl->slice_adaptor->fetch_by_region( 
									    'chromosome', 
									    $chr_name, 
									    $args{slice_start}, 
									    $args{slice_end}
									   );
    $args{strand} = $args{gene}->strand() > 0 ? '+' : '-';
    
    return %args;
}


# this is maybe not the most logical place for this function to live?
#
# input: an array of hashrefs, where each hashref has some way of
# storing start and end coordinates 
# 
# output: sort that array sensibly

sub sort_tags {
    my $class = shift;
    my %args = @_;

    my @tags  = @{$args{tags}}; # array of tag information
    my $start = $args{start}; 	# name of hash key for start location
    my $end   = $args{end}; 	# name of hash key for end location

    # default the keys to 'start' and 'end' if not provided
    $start = 'start' unless (defined $start);
    $end   = 'end'   unless (defined $end);

    # sort
    foreach my $t (@tags) {
	# make sure all start coords are less than the corresponding end coord
	($t->{$start}, $t->{$end}) = sort { $a <=> $b } ($t->{$start}, $t->{$end});
    }
    # then sort the entire list by start coordinate
    @tags = sort { $a->{$start} <=> $b->{$start} } @tags;

    return @tags;
}


1;
