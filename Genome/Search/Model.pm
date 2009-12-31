package Genome::Search::Model;

use strict;
use warnings;

use Genome;


class Genome::Search::Model { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'model'
        }
    ]
};

sub get_document {
    my $class = shift();
    my $model = shift();
    
    my $self = $class->_singleton_object;
    
    my $content = sprintf("%s %s", $model->processing_profile_name, $model->data_directory);
    #print $content, "\n";

    my %field_params = (class => ref($model),
                        title => $model->name,
                        id => $model->id,
                        timestamp => (defined $model->creation_date ? $model->creation_date : "1999-1-1 00:00:00 CST"),
                        content => (defined $content ? $content : ""),
                        type => $self->type,
    );

    my @fields;
    for (keys %field_params) {
            my $value = $field_params{$_};
            if ($_ eq "timestamp") {
                my ($a, $b) = split / /, $value; 
                $value = sprintf("%sT%sZ", $a, $b); 
            }
            push @fields, WebService::Solr::Field->new($_ => $value);
    }

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

#OK!
1;
