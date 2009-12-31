package Genome::Search::ModelGroup;

use strict;
use warnings;

use Genome;


class Genome::Search::ModelGroup { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'modelgroup'
        }
    ]
};

sub get_document {
    my $class = shift();
    my $model_group = shift();
    
    my $self = $class->_singleton_object;
    
    my @fields;

    my @models = $model_group->models;
    my $content = join(' ', $model_group->id, map( ($_->genome_model_id, $_->name), @models) );

    push @fields, WebService::Solr::Field->new( class => ref($model_group) );
    push @fields, WebService::Solr::Field->new( title => $model_group->name() );
    push @fields, WebService::Solr::Field->new( id => $model_group->id() );
    push @fields, WebService::Solr::Field->new( timestamp => '1999-01-01T01:01:01Z');
    push @fields, WebService::Solr::Field->new( content => $content ? $content : '' );
    push @fields, WebService::Solr::Field->new( type => $self->type );

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

#OK!
1;
