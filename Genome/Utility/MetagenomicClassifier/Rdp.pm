package Genome::Utility::MetagenomicClassifier::Rdp;

use strict;
use warnings;

require Bio::Taxon;
use Data::Dumper 'Dumper';
use Genome::InlineConfig;
require Genome::Utility::FileSystem;
require Genome::Utility::MetagenomicClassifier;
require Genome::Utility::MetagenomicClassifier::SequenceClassification;

$ENV{PERL_INLINE_JAVA_JNI} = 1;
use Inline(
    Java => <<'END', 
      import edu.msu.cme.rdp.classifier.rrnaclassifier.*;

      class FactoryInstance {
         static ClassifierFactory f = null;

         public FactoryInstance() {
         }
         public FactoryInstance(String property_path){
            ClassifierFactory.setDataProp(property_path);
            try {
                f = ClassifierFactory.getFactory();
            }
            catch (java.lang.Exception e) {
                e.printStackTrace(System.out);
            }
         }

         public Classifier createClassifier() {
            return f.createClassifier();
         }

      };
END

    AUTOSTUDY => 1,
    CLASSPATH => '/gsc/scripts/lib/java/rdp_classifier-2.1.jar',
    STUDY => [
        'edu.msu.cme.rdp.classifier.rrnaclassifier.ClassifierFactory',
        'edu.msu.cme.rdp.classifier.rrnaclassifier.Classifier',
        'edu.msu.cme.rdp.classifier.rrnaclassifier.ClassificationResult',
        'edu.msu.cme.rdp.classifier.rrnaclassifier.RankAssignment',
        'edu.msu.cme.rdp.classifier.readseqwrapper.ParsedSequence',
        'edu.msu.cme.rdp.classifier.readseqwrapper.Sequence',
    ],
    PACKAGE => 'main',
    DIRECTORY => Genome::InlineConfig::DIRECTORY(),
    EXTRA_JAVA_ARGS => '-Xmx1000m',
    JNI => 1,
) ;

sub new {
    my ($class, %params) = @_;
    
    my $self = bless \%params, $class;

    my $classifier_properties_path = '/gsc/scripts/share/rdp/';
    if ($self->{training_path}) {
        $classifier_properties_path = $self->{training_path};
    }
    elsif ($self->{training_set}) {
        $classifier_properties_path .= $self->{training_set}.'/';
    }

    $classifier_properties_path .= 'rRNAClassifier.properties';

    Genome::Utility::FileSystem->validate_file_for_reading($classifier_properties_path)
        or return;

    my $factory = new FactoryInstance($classifier_properties_path);
    $self->{'classifier'} = $factory->createClassifier();

    return $self;
}

sub get_training_set {
    return $_[0]->{training_set};
}

sub classify {
    my ($self, $seq) = @_;

    unless ( $seq ) {
        #$self->error_message("No sequence to classify");
        return;
    }

    if ($seq->length < 200) {
        #$self->error_message("Sequence to short");
        return;
    }
    
    my $parsed_seq = new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->display_name, $seq->seq);
    my $complemented = $self->{'classifier'}->isSeqReversed($parsed_seq);
    my $classification_result = $self->{'classifier'}->classify($parsed_seq);
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
    return $self->{'classifier'}->isSeqReversed($parsed_seq);
}

sub _build_taxon_from_classification_result {
    my ($self, $classification_result) = @_;

    my $assignments = $classification_result->getAssignments()->toArray();

    my @taxa;
    for my $assignment ( @$assignments ) {
        # print Dumper([map{ $_->getName } @{$assignment->getClass->getMethods}]);
        # Methods are: getConfidence, getTaxid, getName, getRank
        push @taxa, Genome::Utility::MetagenomicClassifier->create_taxon(
            id => $assignment->getName,
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
