package Genome::Search;

use strict;
use warnings;

#When loading objects this has already been done (or how did we get the objects?)
#When pulling out of the cache, don't need this either.  There's a require below for when we need it.
#use Genome;

use WebService::Solr;
use MRO::Compat;
use Cache::Memcached;

class Genome::Search { 
    is => 'UR::Singleton',
    doc => 'This module contains methods for adding and updating objects in the Solr search engine.',
    has => [
        solr_server_location => {
            is => 'Text',
            default_value => 'http://localhost:8983/solr', #'http://solr', #Dev. location: 'http://aims-dev:8080/solr'
            doc => 'Location of the Solr server',
        },
        _solr_server => {
            is => 'WebService::Solr',
            is_transient => 1,
        },
        solr_server => {
            calculate_from => ['_solr_server', 'solr_server_location',],
            calculate => q{ return $_solr_server || WebService::Solr->new($solr_server_location) }
        },
        memcached_server_location => {
            is => 'Text',
            default_value => 'localhost:11212',#'imp:11211',
        },
        _memcached_server => {
            is => 'Cache::Memcached',
            is_transient => 1,
        },
        memcached_server => {
            calculate_from => ['_memcached_server', 'memcached_server_location',],
            calculate => q{ return $_memcached_server || new Cache::Memcached {'servers' => [$memcached_server_location], 'debug' => 0, 'compress_threshold' => 10_000,} }
        },
        cache_timeout => {
            is => 'Integer',
            default_value => 0,
            doc => 'Number of seconds for a document to persist in memcached.  Set to 0 for forever. [Note: If > 30 days, memcached instead uses the value as the timestamp at which the information should be expired.'
        }
    ],
};


###  Index accessors  ###

sub search {
    my $class = shift;
    my $query = shift;
    my $webservice_solr_options = shift;
    
    my $self = $class->_singleton_object;
    my $response = $self->solr_server->search($query, $webservice_solr_options);
    
    #TODO Better error handling--WebService::Solr doesn't handle error responses gracefully.
    return $response;
}

sub is_indexable {
    my $class = shift;
    my $object = shift;

    return $class->_has_solr_xml_view($object);
}

sub _has_solr_xml_view {
    my $class = shift;
    my $object = shift;
    
    my $type = ref $object || $object;
    
    my $classes_to_try = mro::get_linear_isa($type);
    
    #Try increasingly general subtypes until we find an appropriate one
    for my $class_to_try (@$classes_to_try) {
        if(($class_to_try . '::View::Solr::Xml')->isa('Genome::View::Solr::Xml')) {
            return 1;
        }
    }
    
    return 0;
}

sub _has_result_xml_view {
    my $class = shift;
    my $object = shift;
    
    my $type = ref $object || $object;
    
    my $classes_to_try = mro::get_linear_isa($type);
    
    #Try increasingly general subtypes until we find an appropriate one
    for my $class_to_try (@$classes_to_try) {
        if(($class_to_try . '::View::SearchResult::Xml')->isa('Genome::View::SearchResult::Xml')) {
            return 1;
        }
    }
    
    return 0;    
}


###  Index mutators  ###

sub add {
    my $class = shift;
    my @objects = @_;
    
    my $self = $class->_singleton_object;
    
    my @docs = map($class->generate_document($_), @objects);
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    unless($self->solr_server->add(\@docs)) {
        $self->error_message('Failed to send ' . (scalar @docs) . ' document(s) to Solr.');
        return;
    }
    
    for my $doc (@docs) {
        my $result_node = $self->generate_result_xml($doc, undef, 'html');
        
        $self->_cache_result($doc, $result_node);
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
    
    my @docs = map($class->generate_document($_), @objects);
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    my $error_count = $class->_delete_by_doc(@docs);
    
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

sub _delete_by_doc {
    my $class = shift;
    my @docs = @_;
    
    my $self = $class->_singleton_object;
    my $solr = $self->solr_server;
    my $memcached = $self->_memcached_server;
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    my $error_count = 0;
    for my $doc (@docs) {
        if($solr->delete_by_id($doc->value_for('id'))) {
            $memcached->delete($self->cache_key_for_doc($doc));
        } else {
            $error_count++;
        }
    }
    
    return $error_count;
}

sub clear {
    my $class = shift;
    
    my $self = $class->_singleton_object;
    
    return 1 if UR::DBI->no_commit; #Prevent automated index manipulation when changes certainly won't be committed
    
    my $solr = $self->solr_server;
    
    $solr->delete_by_query('*:*'); #Optimized by solr for fast index clearing
    $solr->optimize(); #Prevent former entries from influencing future index
    
    #$self->status_message('Solr index cleared.');
    
    #NOTE: The memcached information is not cleared at this point.
    #However, anything added to search will trigger a cache update.
    
    return 1;
}

sub cache_key_for_doc {
    my $class = shift;
    my $doc = shift;
    
    return 'genome_search:' . $doc->value_for('id');
}



###  XML Generation for results  ###

sub generate_pager_xml {
    my $class = shift;
    my $pager = shift;
    my $xml_doc = shift || XML::LibXML->createDocument();
    
    my $page_info_node = $xml_doc->createElement('page-info');
    
    $page_info_node->addChild( $xml_doc->createAttribute('previous-page', $pager->previous_page) )
        if $pager->previous_page;    
    $page_info_node->addChild( $xml_doc->createAttribute('current-page', $pager->current_page) );
    $page_info_node->addChild( $xml_doc->createAttribute('next-page', $pager->next_page) )
        if $pager->next_page;
    $page_info_node->addChild( $xml_doc->createAttribute('last-page', $pager->last_page) );
    
    return $page_info_node;
}

sub generate_result_xml {
    my $class = shift;
    my $doc = shift;
    my $xml_doc = shift || XML::LibXML->createDocument();
    my $format = shift || 'xml';
    
    require Genome; #It is only at this point that we actually need to load other objects
    
    my $object_class = $doc->value_for('class');
    
    $object_class->can('isa'); #Force class autoloading
    
    if($class->_has_result_xml_view($object_class)) {
        
        my $object_id = $doc->value_for('object_id');
        
        unless($object_id) {
            #Fall back on old way of storing id--this can be removed after all snapshots in use set object_id in Solr
            $object_id = $doc->value_for('id');
            ($object_id) = $object_id =~ m/.*?(\d+)$/;
        } 
        
        my $object = $object_class->get($object_id);
        
        unless($object) {
            $class->_delete_by_doc($doc); #Entity in index that no longer exists--clear it out
        }
        return unless $object;
        
        my %view_args = (
            perspective => 'search-result',
            toolkit => $format,
            solr_doc => $doc,
        );
        
        if($format eq 'xsl' or $format eq 'html') {
            $view_args{xsl_root} = Genome->base_dir . '/xsl';
        }
        
        my $view = $object->create_view(%view_args);
        my $object_content = $view->content;
        
        if($format eq 'xsl' or $format eq 'html') {
            $object_content =~ s/^<\?.*?\?>//;
        }
        
        my $result_node = $xml_doc->createElement('result');
        
        if($format eq 'xml') {
            my $lib_xml = XML::LibXML->new();
            my $content = $lib_xml->parse_string($object_content);
            
            $result_node->addChild($content->childNodes);
        } else {
            $result_node->addChild($xml_doc->createTextNode($object_content));
        }
        
        return $result_node;
    } else {
        $class->error_message('No suitable search result view found for ' . $object_class . '.');
        return;
    }
}

sub resolve_result_xml_for_document {
    my $class = shift;
    my $doc = shift;
    my $xml_doc = shift || XML::LibXML->createDocument();
    my $format = shift; #For views
    
    if($format eq 'html') {
        my $result_node = $class->_get_cached_result($doc, $xml_doc);
        
        unless($result_node) {
            #Cache miss
            $result_node = $class->generate_result_xml($doc, $xml_doc, $format);
            return unless $result_node;
            
            $class->_cache_result($doc, $result_node)
                if $result_node;
        }
        return $result_node;
    }
    
    return $class->generate_result_xml($doc, $xml_doc, $format);
}

sub _cache_result {
    my $class = shift;
    my $doc = shift;
    my $result_node = shift;
    
    my $self = $class->_singleton_object;
    
    my $html_to_cache = $result_node->childNodes->string_value;
    
    my $memcached = $self->_singleton_object->memcached_server;
    
    return 1 if UR::DBI->no_commit; #Don't try to manipulate the cache with test code
    
    return $memcached->set($self->cache_key_for_doc($doc), $html_to_cache, $self->cache_timeout);
}

sub _get_cached_result {
    my $class = shift;
    my $doc = shift;
    my $xml_doc = shift;
    
    my $memcached = $class->_singleton_object->memcached_server;
    
    my $cache_key = $class->cache_key_for_doc($doc);
    my $html_snippet = $memcached->get($cache_key);
    
    #Cache miss
    return unless $html_snippet;
    
    my $result_node = $xml_doc->createElement('result');
    $result_node->addChild($xml_doc->createTextNode($html_snippet));
    
    return $result_node;
}

###  Search "document" creation/delegation  ###

sub generate_document {
    my $class = shift;
    my $object = shift;
    
    if($class->_has_solr_xml_view($object)) {
        my $view = $object->create_view(perspective => 'solr', toolkit => 'xml');
        return $view->content_doc;
    }
    
    die('To make an object searchable create an appropriate ::View::Solr::Xml that inherits from Genome::View::Solr::Xml.');
}

###  Callbacks for automatically updating index  ###

sub _commit_callback {
    my $class = shift;
    my $object = shift;
    
    return unless $object;
    
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
    
    return unless $object;
    
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
  
  Genome::Search->search($query, $options);

=head1 DESCRIPTION

This class adds, updates, and deletes entries for objects from the Solr index.

=head1 METHODS

=over 4

=item search

Query the Solr index.

=item is_indexable

Determine if an appropriate subclass exists to add the object to the Solr index.

=item add

Adds one or more objects to the Solr index.

=item update

An alias for add. Solr's add method automatically overwrites any existing entry for the object.

=item delete

Removes one or more objects from the Solr index.

=item clear

Removes all objects from the Solr index.

=back

=head1 DETAILS

To make a new type of object indexable by Solr, create a subclass of Genome::View::Solr::Xml for
that object.  For example, to make a Genome::Individual indexable, the class
Genome::Individual::View::Solr::Xml was created.  The class should define the
"type" attribute with an alphanumeric name representing the class in the index
as well as specify what aspects to be included in what search fields.

Additionally, for the display of results, appropriate ::View::SearchResult::Xml and
::View::SearchResult::Html classes should be created for each class where a
::View::Solr::Xml has been defined.

=head1 SEE ALSO

Genome::Individual::View::Solr::Xml
Genome::Individual::View::SearchResult::Xml
Genome::Individual::View::SearchResult::Html

=cut
