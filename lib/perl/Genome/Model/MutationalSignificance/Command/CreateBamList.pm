package Genome::Model::MutationalSignificance::Command::CreateBamList;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateBamList {
    is => ['Command::V2'],
    has_input => [
        somatic_variation_builds => {
            is => 'Genome::Model::Build::SomaticVariation',
            is_many => 1,    
        },
    ],
    has_output => [
        bam_list => {
            is => 'Text',},
    ],
};

sub execute {
    my $self = shift;

    my $out_string = "";

    foreach my $build ($self->somatic_variation_builds) {
        $out_string .= $build->subject->name; #TODO: I don't think this is safe
        $out_string .= "\t";
        $out_string .= $build->normal_bam;
        $out_string .= "\t";
        $out_string .= $build->tumor_bam;
        $out_string .= "\n";
    }

    $self->bam_list($out_string);
    $self->status_message('Created BAM list');
    return 1;
}

1;
