
package Genome::Model::Command::Report::MutationDiagram;

use strict;
use warnings;

use Genome;
use MG::MutationDiagram;

class Genome::Model::Command::Report::MutationDiagram {
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        maf     => { type => 'String',  doc => "MAF file"},
	genes   => { type => 'String',  doc => "comma separated list of (hugo) gene names (uppercase)--default is ALL", is_optional => 1},
    ],
};

sub help_brief {
    "report mutations as a (svg) diagram"
}

sub help_synopsis {
    return <<"EOS"
genome-model report mutation-diagram  --maf my.maf
EOS
}

sub help_detail {
    return <<"EOS"
Generates (gene) mutation diagrams from a MAF file.
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;
    my $maf_file = $self->maf;
    my $maf_obj = new MG::MutationDiagram(
        maf_file => $maf_file,
        hugos => $self->genes
    );
    #use Data::Dumper;
    #$Data::Dumper::Indent = 1;
    # my $data = $maf_obj->Data();
    # print Dumper($data);
    return 1;
}


1;

