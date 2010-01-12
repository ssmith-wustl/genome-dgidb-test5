package Genome::Search;

use strict;
use warnings;

use WebService::Solr;
use MRO::Compat;

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
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    unless($self->_solr_server->add(\@docs)) {
        $self->error_message('Failed to send ' . (scalar @docs) . ' document(s) to Solr.');
        return;
    }

    #$self->status_message('Sent ' . (scalar @docs) . ' document(s) to Solr.');
    return 1;
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
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    my $error_count = 0;
    for my $doc (@docs) {
        unless($self->_solr_server->delete_by_id($doc->value_for('id'))) {
            $error_count++;
        }
    }
    
    my $deleted_count = scalar(@docs) - $error_count;
#    if($deleted_count) {
#        $self->status_message('Removed ' . $deleted_count . ' document(s) from Solr.');
#    }
    if($error_count) {
        $self->error_message('Failed to remove ' . $error_count . ' document(s) from Solr.');
        return;
    }
    
    return $deleted_count || 1;
}

sub clear {
    my $class = shift;
    
    my $self = $class->_singleton_object;
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    $self->_solr_server->delete_by_query('*:*'); #Optimized by solr for fast index clearing
    $self->_solr_server->optimize(); #Prevent former entries from influencing future index
    
    #$self->status_message('Solr index cleared.');
    
    return 1;
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
    
    return if $type =~ /::Ghost$/;  #Don't try to (de)index deleted references.
    
    my $classes_to_try = mro::get_linear_isa($type);
    
    #Try increasingly general subtypes until we find an appropriate one
    for my $class_to_try (@$classes_to_try) {
        my @type_parts = split('::', $class_to_try);
        shift @type_parts if $type_parts[0] eq 'Genome'; #Avoid redundant folder in search tree
    
        my $subclass .= join('::', 'Genome::Search', @type_parts);
        
        if($subclass->can('get_document') and $object->isa($class_to_try)) {
            return $subclass;
        }
    }
    
    #No appropriate search module found
    return;
}

sub is_indexable {
    my $class = shift;
    my $object = shift;
    
    return $class->_resolve_subclass_for_object($object) ? 1 : 0;
}


### Callbacks for automatically updating index

sub _commit_callback {
    my $class = shift;
    my $object = shift;
    
    eval {
        if($class->is_indexable($object)) {
            $class->add($object);
        }
    };
    
    if($@) {
        my $self = $class->_singleton_object;
        $self->error_message('Error in commit callback: ' . $@);
        return;
    }
    
    return 1;
}

sub _delete_callback {
    my $class = shift;
    my $object = shift;
    
    eval {
        if($class->is_indexable($object)) {
            $class->delete($object);
        }
    };
    
    if($@) {
        my $self = $class->_singleton_object;
        $self->error_message('Error in delete callback: ' . $@);
        return;
    }
    
    return 1;
}

#This should be called from Genome.pm, so typically it won't need to be called elsewhere.
sub register_callbacks {
    my $class = shift;
    my $module_to_observe = shift;
    
    $module_to_observe->create_subscription(
        method => 'commit',
        callback => sub { $class->_commit_callback(@_); },
    );
    
    $module_to_observe->create_subscription(
        method => 'delete',
        callback => sub { $class->_delete_callback(@_); }
    );
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
By convention, '1999-01-01T01:01:01Z' is used when the creation date is unknown.

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

