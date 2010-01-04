package Genome::Search;

use strict;
use warnings;

use Genome;
use WebService::Solr;

class Genome::Search { 
    is => 'UR::Singleton',
    doc => 'This module contains methods for adding and updating objects in the Solr search engine.',
    has => [
       solr_server_location => {
           is => 'Text',
           default_value => 'http://solr', #Dev. location: 'http://aims-dev:8080/solr'
           doc => 'Location of the Solr server',
       },
       _solr_server => {
           calculate_from => 'solr_server_location',
           calculate => q|WebService::Solr->new($solr_server_location)|
       },
       type => {
           is => 'Text',
           default_value => 'unknown',
           doc => 'The type represented by the document--override this in subclasses'
       }
    ],
};

sub add {
    my $class = shift;
    my @objects = @_;
    
    my $self = $class->_singleton_object;
    
    my @docs = map($class->resolve_document_for_object($_), @objects);
    
    if($self->_solr_server->add(\@docs)) {
        $self->status_message('Sent ' . (scalar @docs) . ' documents to Solr');
    } else {
        $self->error_message('Failed to send ' . (scalar @docs) . ' documents to Solr');
    }
}

sub update {
    my $class = shift;
    
    #In solr, updating a record is the same as creating it--if the ID matches it overwrites
    return $class->add(@_);
}

sub delete {
    my $class = shift;
    my @objects = @_;
    
    my $self = $class->_singleton_object;
    
    my @docs = map($class->resolve_document_for_object($_), @objects);
    my $error_count = 0;
    for my $doc (@docs) {
        unless($self->_solr_server->delete_by_id($doc->value_for('id'))) {
            $error_count++;
        }
    }
    
    my $deleted_count = scalar(@docs) - $error_count;
    if($deleted_count) {
        $self->status_message('Removed ' . $deleted_count . ' documents from Solr.');
    }
    if($error_count) {
        $self->error_message('Failed to remove ' . $error_count . ' documents from Solr.');
    }
}

sub clear {
    my $class = shift;
    
    my $self = $class->_singleton_object;
    
    $self->_solr_server->delete_by_query('*:*'); #Optimized by solr for fast index clearing
    $self->_solr_server->optimize();
}

sub get_document {
    my $class = shift;
    
    #Possibly create a generic document?
    die('This method should be implemented by the subclass.');
}

sub resolve_document_for_object {
    my $class = shift;
    my $object = shift;
    
    my $self = $class->_singleton_object;
    
    my $subclass = $class->_resolve_subclass_for_object($object);
    
    unless($subclass) {
        $self->warning_message('No appropriate search module found for type: ' . ref $object);
        return;
    }
    
    return $subclass->get_document($object);
}

sub _resolve_subclass_for_object {
    my $class = shift;
    my $object = shift;
    
    my $type = ref $object;
    return unless $type;
    
    my @type_parts = split('::', $type);
    shift @type_parts if $type_parts[0] eq 'Genome'; #Avoid redundant folder in search tree
    
    my $subclass_base = 'Genome::Search';
    while(@type_parts) {
        #Try increasingly general subtypes until we find an appropriate one
        my $subclass .= join('::', $subclass_base, @type_parts);
        
        if($subclass->can('get_document')) {
            return $subclass;
        }
        
        pop @type_parts;
    }
    
    #No appropriate search module found
    return;
}

sub is_indexable {
    my $class = shift;
    my $object = shift;
    
    return $class->_resolve_subclass_for_object($object) ? 1 : 0;
}

#OK!
1;


=pod

=head1 NAME

Genome::Search

=head1 SYNOPSIS

  Genome::Search->add(@objects);
  Genome::Search->delete(@objects);
  Genome::Search->is_indexable($object);

=head1 DESCRIPTION

This class adds, updates, and deletes entries for objects from the Solr index.

=head1 METHODS

=over 4

=item add

Adds one or more objects to the Solr index.

=item update

An alias for add. Solr's add method automatically overwrites any existing entry for the object.

=item delete

Removes one or more objects from the Solr index.

=item clear

Removes all objects from the Solr index.

=item is_indexable

Determine if an appropriate subclass exists to add the object to the Solr index.

=back

=head1 DETAILS

To make a new type of object indexable by Solr, create a subclass of this
class.  For example, to make a Genome::Individual indexable, the class
Genome::Search::Individual was created.  The class should define the
"type" attribute with an alphanumeric name representing the class in the index
as well as a get_document method that produces a WebService::Solr::Document
representing the object  (See Genome::Search::Individual for an example).  The
fields needed for the document are:

=over 4

=item class

Typically ref $object -- use this unless there's a good reason not to

=item title

A human-readable name unique to this object

=item id

A unique identifier for the object -- this is what Solr uses to distinguish items

=item timestamp

The time when the object was created in the format 'yyyy-mm-ddThh:mm:ssZ'.
By convention, '1999-01-01T01:01:01Z' should be used when the creation date is unknown.

=item content

Any relevant information for the object that would help search for it, whitespace delimited.
(e.g., the gender for an individual)

=item type

An alphanumeric string representing the type of object.  This allows queries of the form
"type:query" to locate all objects of a given type.  This should match the
"type" attribute for the implementing class.
 
=back

=head1 SEE ALSO

Genome::Search::Individual

=cut

