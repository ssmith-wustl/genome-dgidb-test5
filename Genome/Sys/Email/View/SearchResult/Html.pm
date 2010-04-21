package Genome::Sys::Email::View::SearchResult::Html;

use strict;
use warnings;

use Genome;

class Genome::Sys::Email::View::SearchResult::Html {
    is => 'Genome::View::SearchResult::Html',
};

sub _update_view_from_subject {
    my $self = shift;
    
    my $solr_doc = $self->solr_doc;
    if($solr_doc) {
        my $subject = $self->subject;
        if($subject and not $subject->is_initialized) {
            $subject->initialize($solr_doc);
        }
    }
    
    return $self->SUPER::_update_view_from_subject(@_);
}

1;
