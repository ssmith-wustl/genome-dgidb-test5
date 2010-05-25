
package Genome::Search::Query;

use strict;
use warnings;

our $PAGE_SIZE = 50;

class Genome::Search::Query {
    is => 'UR::Value',
    id_by => [
        query => { is => 'Text' },
        page => { is => 'Number' }
    ],
    has => [
        result_objects => {
            is => 'Genome::Search::Result',
            reverse_as => 'query',
            is_many => 1,
        },
        results => {
            is_many => 1,
            via => 'result_objects',
            to => 'subject'
        },
        page_size => {
            is_constant => 1,
            is_class_wide => 1,
            value => $PAGE_SIZE
        },
        total_found => {
            is => 'Number'
        }
    ]
};

sub get {
    my $class = shift;
    if (@_ > 1 && @_ % 2 == 0) {
        my %args = (@_);
        $args{page} = 1 unless exists $args{page};
        @_ = %args;
    }

    return $class->SUPER::get(@_);
}

sub total_found {
    my $self = shift;

    unless (exists $self->{executed} && $self->{executed}) {
        $self->__total_found($self->execute);
    }
    $self->__total_found;
}

sub results {
    my $self = shift;

    unless (exists $self->{executed} && $self->{executed}) {
        $self->__total_found($self->execute);
    }

    return $self->__results;
}

sub result_objects {
    my $self = shift;

    unless (exists $self->{executed} && $self->{executed}) {
        $self->__total_found($self->execute);
    }

    return $self->__result_objects;
}

sub execute {
    my $self = shift;
    $self->{executed} = 1;

    my $response = Genome::Search->search(
        $self->query,
        {
            rows  => $PAGE_SIZE,
            start => $PAGE_SIZE * ( $self->page - 1 )
        }
    );

    foreach my $doc ($response->docs) {
        my $subject_class = $doc->value_for('class');
        my $subject_id = $doc->value_for('object_id');

        Genome::Search::Result->create(
            query_string => $self->query,
            page => $self->page,
            subject_class_name => $subject_class,
            subject_id => $subject_id
        );
    }

    $response->content->{response}->{numFound};
}

