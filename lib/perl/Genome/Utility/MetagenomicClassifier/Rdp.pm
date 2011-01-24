package Genome::Utility::MetagenomicClassifier::Rdp;

use strict;
use warnings;

require Bio::Taxon;
require Carp;
use Data::Dumper 'Dumper';
use Genome::InlineConfig;
require Genome::Sys;
require Genome::Utility::MetagenomicClassifier;
require Genome::Utility::MetagenomicClassifier::SequenceClassification;

class Genome::Utility::MetagenomicClassifier::Rdp{
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

    unless ( $seq ) {
        Carp::confess("No sequence given to classify");
        return;
    }

    if ($seq->length < 50) {
        print STDERR "Can't classify sequence (".$seq->id."). Sequence length must be at least 50 bps.\n";
        return;
    }
    
    my $parsed_seq;
    eval{
        $parsed_seq = new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->display_name, $seq->seq);
    };
    unless ( $parsed_seq ) {
        print STDERR "Can't classify sequence (".$seq->id."). Can't create rdp parsed sequence.\n";
        return;
    }

    my $classification_result;
    eval{
        $classification_result = $self->{'classifier'}->classify($parsed_seq);
    };
    unless ( $classification_result ) {
        print STDERR "Can't classify sequence (".$seq->id."). No classification result was returned from the classifier.\n";
        return;
    }

    my $complemented = $self->_is_seq_reversed($parsed_seq);

    my $taxon = $self->_build_taxon_from_classification_result($classification_result);

    return Genome::Utility::MetagenomicClassifier::SequenceClassification->new(
        name => $seq->display_name,
        complemented => $complemented,
        classifier => 'rdp',
        taxon => $taxon,
    );
}

sub is_reversed {
    my $self = shift;
    my $seq = shift;
    my $parsed_seq = new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->display_name, $seq->seq);
    return $self->_is_seq_reversed($parsed_seq);
}

sub _is_seq_reversed {
    die("abstract method.  define in inheriting class");
}

sub _build_taxon_from_classification_result {
    my ($self, $classification_result) = @_;

    my $assignments = $classification_result->getAssignments()->toArray();

    my @taxa;
    for my $assignment ( @$assignments ) {
        # print Dumper([map{ $_->getName } @{$assignment->getClass->getMethods}]);
        # Methods are: getConfidence, getTaxid, getName, getRank	
	my $id = $assignment->getName;
	$id =~ s/\s+/_/g;
        push @taxa, Genome::Utility::MetagenomicClassifier->create_taxon(
	    id => $id,
            rank => ( @taxa ? $assignment->getRank : 'root'),
            tags => {
                confidence => $assignment->getConfidence,
            },
            ancestor => ( @taxa ? $taxa[$#taxa] : undef ),
        );
    }

    return $taxa[0];
}

1;

#$HeadURL$
#$Id$
