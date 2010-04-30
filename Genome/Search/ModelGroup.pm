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

sub _add_details_result_xml {
    my $class = shift;
    my $doc = shift;
    my $result_node = shift;
    
    my $xml_doc = $result_node->ownerDocument;

    my $content = $doc->value_for('content');
    my ($model_group_id) = $doc->value_for('id') =~ /(\d+)/;
    
    my $model_group_url = "/view/Genome/ModelGroup/status.html?id=$model_group_id";
    my $model_group_url_node = $result_node->addChild( $xml_doc->createElement("url") );
    $model_group_url_node->addChild( $xml_doc->createTextNode($model_group_url) );

    my $summary = $class->_model_group_summary($content);
    my $summary_node = $result_node->addChild( $xml_doc->createElement('summary') );
    $summary_node->addChild( $xml_doc->createTextNode( $summary) );
    
    return $result_node;
}

sub generate_document {
    my $class = shift();
    my $model_group = shift();
    
    my $self = $class->_singleton_object;
    
    my @fields;

    my @models = $model_group->models;
    my $content = join(' ', $model_group->id, map( ($_->genome_model_id, $_->name), @models) );

    push @fields, WebService::Solr::Field->new( class => ref($model_group) );
    push @fields, WebService::Solr::Field->new( title => $model_group->name() );
    push @fields, WebService::Solr::Field->new( id => 'model-group' . $model_group->id() );
    push @fields, WebService::Solr::Field->new( timestamp => '1999-01-01T01:01:01Z');
    push @fields, WebService::Solr::Field->new( content => $content ? $content : '' );
    push @fields, WebService::Solr::Field->new( type => $self->type );

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

sub _model_group_summary {
     my $class = shift();
     my ($content) = @_;

     $content =~ s/\d+\s/ /g;

     my @content = split(/ /, $content);
     my $end = '';
     if(scalar @content > 3) {
         $end = ' ...';
     }

     @content = splice(@content, 0, 3);
     my $summary = join(' ', @content) . $end;

     return $summary;
}

#OK!
1;
