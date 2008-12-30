package Genome::Model::Tools::MetagenomicClassifier::Rdp;

use strict;
use warnings;

use Bio::Seq;
use Bio::SeqIO;
use Bio::Taxon;

use Genome::InlineConfig;

use Inline (
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
) ;

class Genome::Model::Tools::MetagenomicClassifier::Rdp {
    is => 'Command',
    has => [ 
        input_file =>       {
            type => 'String',
            is_optional => 0, ###
            doc => "path to fasta file"
        },

        output_file =>        { 
            type => 'String',
            is_optional => 1, ###
            doc => "path to output file"
        },
    ],
    has_optional => [
        training_set => {
            type => 'String',
            doc => 'name of training set (broad)',
        },
    ],
};

sub execute {
    my $self = shift;
    
    my $in = Bio::SeqIO->new(-file => $self->input_file);

    my $out;
    if ($self->output_file) {
        $out = new IO::File(">".$self->output_file);
    }
    unless ($out) {
        $out = new IO::Handle; 
        $out->fdopen(fileno(STDOUT),"w");
    }

    while (my $seq = $in->next_seq()) {
        my $complemented = $self->is_reversed($seq);
        my $classification = $self->classify($seq);
        $self->write_classification($out, $seq, $complemented,$classification);
    }
    $in->close();
    $out->close();
}

sub write_classification {
    my $self = shift;
    my $out = shift;
    my $seq = shift;
    my $complemented = shift;
    my $classification = shift;

    $out->print($seq->display_name);
    $out->print(";");
    if ($complemented) {
        $out->print("-");
    }
    else {
        $out->print(" ");
    }
    $out->print(";");
    
    do {
        $out->print($classification->id.":");
        my ($conf) = $classification->get_tag_values('confidence');
        $out->print("$conf;");
        ($classification) = $classification->get_Descendents();
    }
    until ($classification->is_Leaf());
    $out->print($classification->id.":");
    my ($conf) = $classification->get_tag_values('confidence');
    $out->print("$conf;\n");
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $classifier_properties_path = '/gsc/scripts/share/rdp/';
    if ($self->training_set) {
        $classifier_properties_path .= $self->training_set.'/';
    }
    $classifier_properties_path .= 'rRNAClassifier.properties';

    my $factory = new FactoryInstance($classifier_properties_path);
    $self->{'classifier'} = $factory->createClassifier();

    return $self;
}

sub classify {
    my $self = shift;
    my $seq = shift;
    my $parsed_seq = new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->display_name, $seq->seq);

    my $classification_result = $self->{'classifier'}->classify($parsed_seq);

    return $self->_build_classification($classification_result);
}

sub is_reversed {
    my $self = shift;
    my $seq = shift;
    my $parsed_seq = new edu::msu::cme::rdp::classifier::readseqwrapper::ParsedSequence($seq->display_name, $seq->seq);
    return $self->{'classifier'}->isSeqReversed($parsed_seq);
}

sub _build_classification {
    my $self = shift;
    my $classification_result = shift;

    my $root = undef;
    my $prevTaxon = undef;

    my $assignments = $classification_result->getAssignments()->toArray();
    foreach my $assignment (@$assignments) {
        my $taxon = new Bio::Taxon();
        $taxon->id($assignment->getName());
        $taxon->add_tag_value('confidence', $assignment->getConfidence());
        if ($prevTaxon) {
            $prevTaxon->add_Descendent($taxon);
        }
        else {
            $root = $taxon;
        }
        $prevTaxon = $taxon;
    }

    return $root;
}

sub help_brief {
    "rdp classifier",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools metagenomic-classifier rdp    
EOS
}

1;
