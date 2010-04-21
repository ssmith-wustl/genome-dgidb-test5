package Genome::Sys::Email::View::SearchResult::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sys::Email::View::SearchResult::Xml {
    is => 'Genome::View::SearchResult::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            default => [
                'id',
                'subject',
                'blurb',
                'body',
                'list_name',
                'month',
                'message_id',
                'mail_server_path',
                'mail_list_path',
            ]
        }
    ]
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
