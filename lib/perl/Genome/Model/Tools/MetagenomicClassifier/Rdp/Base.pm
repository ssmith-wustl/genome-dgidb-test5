package Genome::Model::Tools::MetagenomicClassifier::Rdp::Base;

use strict;
use warnings;

use Genome::InlineConfig;

class Genome::Model::Tools::MetagenomicClassifier::Rdp::Base {
    is_abstract => 1,
};

$ENV{PERL_INLINE_JAVA_JNI} = 1;

sub get_training_path {
    my $class = shift;
    my $training_set = shift;

    $training_set |= '';
    return "/gsc/scripts/share/rdp/$training_set";
}

sub create {
    my $class = shift;
    return $class->new(@_);
}
sub new {
    my ($class, %params) = @_;
    
    my $self = bless \%params, $class;

    my $classifier_properties_path = '/gsc/scripts/share/rdp/';
    if ($self->{training_path}) {
        $classifier_properties_path = $self->{training_path}.'/';
    }
    elsif ($self->{training_set}) {
        $classifier_properties_path .= $self->{training_set}.'/';
    }

    $classifier_properties_path .= 'rRNAClassifier.properties';

    Genome::Sys->validate_file_for_reading($classifier_properties_path)
        or return;

    my $factory = new FactoryInstance($classifier_properties_path);
    $self->{'factory'} = $factory;
    $self->{'classifier'} = $factory->createClassifier();

    return $self;
}

sub get_training_version {
    my $self = shift;
    my $version = $self->{'factory'}->getHierarchyVersion();
    return $version;
}

sub get_training_set {
    return $_[0]->{training_set};
}

sub classify {
    my ($self, $seq) = @_;

    return if not $self->verify_seq($seq);

    my $parsed_seq = eval{
        new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->{id}, $seq->{seq});
    };
    if ( not $parsed_seq ) {
        $self->error_message("Can't classify sequence (".$seq->{id}."). Can't create rdp parsed sequence.");
        return;
    }

    # Try to classify 2X - per kathie 2009mar3
    my $classification_result = eval{ $self->{'classifier'}->classify($parsed_seq); };
    if ( not $classification_result ) {
        $classification_result = eval{ $self->{'classifier'}->classify($parsed_seq); };
        if ( not $classification_result ) {
            $self->error_message("Can't classify sequence (".$seq->{seq}."). No classification result was returned from the classifier.");
            return;
        }
    }

    my $complemented = $self->_is_reversed(
        parsed_seq => $parsed_seq,
        classification_result => $classification_result,
    );

    my @assignments = @{$classification_result->getAssignments()->toArray()};
    my %taxa = (
        id => $seq->{id},
        complemented => $complemented,
        classifier => 'rdp',
        root => {
            id => 'Root',
            confidence => $assignments[0]->getConfidence,
        },
    );
    for my $assignment ( @assignments[1..$#assignments] ) {
        # print Dumper([map{ $_->getName } @{$assignment->getClass->getMethods}]);
        # Methods are: getConfidence, getTaxid, getName, getRank	
        my $id = $assignment->getName;
        $id =~ s/\s+/_/g;
        $taxa{ $assignment->getRank || 'root' } = {
            id => $id,
            confidence => $assignment->getConfidence,
        };
    }

    return \%taxa;
}

1;

