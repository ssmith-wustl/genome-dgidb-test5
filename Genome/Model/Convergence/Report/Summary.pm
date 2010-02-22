package Genome::Model::Convergence::Report::Summary;

use strict;
use warnings;

use Genome;

class Genome::Model::Convergence::Report::Summary{
    is => 'Genome::Model::Report',
};

sub description {
    my $self = shift();

    return 'summary of harmonic convergence model';
}

sub _add_to_report_xml {
    my $self = shift();
    
    my $build = $self->build;
    
    my $doc = $self->_xml;

    my $members_node = $doc->createElement('members');
    
    for my $member ($build->members) {
        my $member_node = $members_node->addChild( $doc->createElement('member') );
        
        $member_node->addChild( $doc->createAttribute('id', $member->model->id) );
        $member_node->addChild( $doc->createAttribute('name', $member->model->name) );
    }
    
    $self->_main_node->addChild($members_node);
    
    return 1;
}

1;
