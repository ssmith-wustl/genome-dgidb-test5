package Genome::Individual::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Individual::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'individual'
        },
        default_aspects => {
            is => 'ARRAY,',
            default => [
                {
                    name => 'common_name',
                    position => 'title',
                },
                {
                    name => 'name',
                    position => 'title',
                },
                {
                    name => 'gender',
                    position => 'content',
                },
                {
                    name => 'upn',
                    position => 'content',
                }
            ]
        },
    ]
};


sub _generate_title_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    return $subject->common_name || $self->SUPER::_generate_title_field_data($subject);
}

sub _generate_content_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    my $content = join(' ', $subject->common_name, $subject->name, ($subject->gender || ''));
    
    return $content;
}

1;
