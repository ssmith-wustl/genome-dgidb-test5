package Genome::Search::Query::View::Status::Xml;

use strict;
use warnings;
use Genome;

class Genome::Search::Query::View::Status::Xml {
    is           => 'UR::Object::View::Default::Xml',
    has_constant => [ perspective => { value => 'status', }, ],
};

my $RESULTS_PER_PAGE = 50;

sub _generate_content {
    my $self    = shift;
    my $subject = $self->subject;
    my $format = exists $subject->{format} ? $subject->{format} : 'xml';

    my $query = $subject->query;
    my $page  = $subject->page;

    my $doc          = XML::LibXML->createDocument();
    my $results_node = $doc->createElement('solr-results');

    my $solrQuery = $query;
    my $response  = Genome::Search->search(
        $solrQuery,
        {
            rows  => $RESULTS_PER_PAGE,
            start => $RESULTS_PER_PAGE * ( $page - 1 )
        }
    );

    my $time = UR::Time->now();
    $results_node->addChild( $doc->createAttribute( "generated-at", $time ) );
    $results_node->addChild( $doc->createAttribute( "input-name",   "query" ) );
    $results_node->addChild( $doc->createAttribute( "query",        $query ) );
    $results_node->addChild( $doc->createAttribute( "num-found", $response->content->{'response'}->{'numFound'} ));

    # create query-no-types attribute
    my @params = split /\s+/, $query;
    for ( my $i = $#params ; $i >= 0 ; --$i ) {
        splice @params, $i, 1
          if $params[$i] =~ /(type\:(\S+))/i;
    }
    my $query_no_types = join " ", @params;

    $results_node->addChild(
        $doc->createAttribute( "query-no-types", $query_no_types ) );
    $results_node->addChild(
        Genome::Search->generate_pager_xml( $response->pager, $doc ) );

    my @ordered_docs = sort_solr_docs( $response->docs );

    my @result_nodes =
      Genome::Search->generate_result_xml( \@ordered_docs, $doc, $format );

    for my $result_node (@result_nodes) {
        $results_node->addChild($result_node);
    }

    $doc->setDocumentElement($results_node);

    $doc->toString(1);
}

sub sort_solr_docs {
    my @docs = @_;

    my @ordered_doc_classes = Genome::Search->searchable_classes();

    my %ordered_docs;
    my @everything_else_docs;

    my %docs_by_class;

    for my $solr_doc (@docs) {
        my $this_doc_class = $solr_doc->value_for('class');
        my ($matched_class) =
          grep { $this_doc_class =~ m/$_/ } @ordered_doc_classes;
        if ($matched_class) {
            push @{ $docs_by_class{$matched_class} }, $solr_doc;
        } else {
            push @everything_else_docs, $solr_doc;
        }
    }

    my @doc_classes = keys %docs_by_class;
    my @ordered_docs;

    for my $ordered_class (@ordered_doc_classes) {
        push @ordered_docs, @{ $docs_by_class{$ordered_class} }
          if ( exists $docs_by_class{$ordered_class} );
    }
    push @ordered_docs, @everything_else_docs;

    return @ordered_docs;
}

