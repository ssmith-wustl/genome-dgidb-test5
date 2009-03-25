package Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition {
    is => 'Genome::Model::Command::Build::AmpliconAssembly::PostProcess',
};

#< Beef >#
sub execute {
    my $self = shift;

    return 1;
    unlink $self->build->rdp_file if -e $self->build->rdp_file;
    
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Test->create_broad_classifier;
    my $factory = Genome::Utility::MetagenomicClassifier::PopulationCompositionFactory->instance;
    my $composition = $factory->get_composition(
        classifier => Genome::Utility::MetagenomicClassifier::Rdp->new(
            training_set => 'broad',
        ),
        fasta_file => Genome::Utility::MetagenomicClassifier::TestBase->fasta,
    );

    return 1 if -s $self->build->rdp_file;

    #< Report
    my $report = Genome::Model::Report->create(
        composition => $composition,
    );
    $report->execute;

    #< RDP Output
    my $writer = Genome::Utility::MetagenomicClassifier::Rdp::Writer->create(
        output => ,
    );
    for my $classification ( $composition->clasifications ) {
        $writer->write_classification($classification);
    }

    $self->error_message("RDP classification executed correctly, but a file was not created");
    return;
}

1;

#$HeadURL$
#$Id$
