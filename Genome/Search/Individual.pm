package Genome::Search::Individual;

use strict;
use warnings;

use Genome;


class Genome::Search::Individual { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'individual'
        }
    ]
};

sub get_document {
    my $class = shift();
    my $individual = shift();
    
    my $self = $class->_singleton_object();
    
    my @fields;

    my $content = join(' ', $individual->common_name, ($individual->gender || ''));

    push @fields, WebService::Solr::Field->new( class => ref($individual) );
    push @fields, WebService::Solr::Field->new( title => $individual->common_name() );
    push @fields, WebService::Solr::Field->new( id => $individual->individual_id() );
    push @fields, WebService::Solr::Field->new( timestamp => '1999-01-01T01:01:01Z');
    push @fields, WebService::Solr::Field->new( content => $content ? $content : '' );
    push @fields, WebService::Solr::Field->new( type => $self->type );

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

#OK!
1;
