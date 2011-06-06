package Genome::Model::Tools::MetagenomicClassifier::Rdp::Version2x2;

use strict;
use warnings;

use Genome::InlineConfig;

class Genome::Model::Tools::MetagenomicClassifier::Rdp::Version2x2{
    is => 'Genome::Model::Tools::MetagenomicClassifier::Rdp::Base',
};

use Inline(
    Java => <<'END', 
      import edu.msu.cme.rdp.classifier.rrnaclassifier.*;

      class FactoryInstance {
         static ClassifierFactory f = null;

         public FactoryInstance() {
         }

         public FactoryInstance(String property_path){
            ClassifierFactory.setDataProp(property_path, false);
            try {
                f = ClassifierFactory.getFactory();
            }
            catch (java.lang.Exception e) {
                e.printStackTrace(System.out);
            }
         }

         public FactoryInstance(String property_path, boolean relative){
            ClassifierFactory.setDataProp(property_path, relative);
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

         public String getHierarchyVersion() {
            return f.getHierarchyVersion();
         }

      };
END

    AUTOSTUDY => 1,
    CLASSPATH => '/gsc/scripts/lib/java/rdp_classifier-2.2.jar',
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
    EXTRA_JAVA_ARGS => '-Xmx2000m',
    JNI => 1,
) ;

sub verify_seq {
    my ($self, $seq) = @_;

    if ( not $seq ) {
        Carp::confess("No sequence given to classify");
    }

    unless ( $seq->{id} ) {
        Carp::confess('Seq does not have an id: '.Data::Dumper::Dumper($seq));
    }

    unless ( length $seq->{seq} >= 50) {
        return;
    }

    return 1;
}

sub _is_reversed {
    my ($self, %params) = @_;
    return $params{classification_result}->getSequence()->isReverse();
}

1;

