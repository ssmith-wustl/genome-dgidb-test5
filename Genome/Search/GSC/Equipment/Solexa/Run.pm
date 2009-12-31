package Genome::Search::GSC::Equipment::Solexa::Run;

use strict;
use warnings;

use Genome;


class Genome::Search::GSC::Equipment::Solexa::Run { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'illumina_run'
        }
    ]
};

sub get_document {
    my $class = shift();
    my $solexa_run = shift();
    
    my $self = $class->_singleton_object();
    
    my $lane_samples= $solexa_run->get_dna_by_lane(); # { lanes => samples }
    
    my @samples = map($_->dna_name, values %$lane_samples);
    
    my $timestamp = $solexa_run->get_creation_event->date_scheduled;
    
    if($timestamp) {
        my ($a, $b) = split(/ /, $timestamp);
        $timestamp = $a . 'T' . $b . 'Z';
    } else {
        $timestamp = '1999-01-01T01:01:01Z';
    }
    
    my @fields;
    push @fields, WebService::Solr::Field->new( class     => ref $solexa_run );
    push @fields, WebService::Solr::Field->new( type      => $self->type );
    push @fields, WebService::Solr::Field->new( id        => $solexa_run->er_id() );
    push @fields, WebService::Solr::Field->new( title     => $solexa_run->flow_cell_id() );
    push @fields, WebService::Solr::Field->new( content   => join(',', @samples));
    push @fields, WebService::Solr::Field->new( timestamp => $timestamp );
    
    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

#OK!
1;
