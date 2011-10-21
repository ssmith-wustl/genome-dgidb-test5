package Genome::Command;

use strict;
use warnings;

use Genome;

class Genome::Command {
    is => 'Command::Tree',
};
         
# This map allows the top-level genome commands to be whatever
# we wish, instead of having to match the directory structure.
my %command_map = (
    'disk' => 'Genome::Disk::Command',
    'feature-list' => 'Genome::FeatureList::Command',
    'gene-name' => 'Genome::GeneName::Command',
    'individual' => 'Genome::Individual::Command',
    'instrument-data' => 'Genome::InstrumentData::Command',
    'library' => 'Genome::Library::Command',
    'model' => 'Genome::Model::Command',
    'model-group' => 'Genome::ModelGroup::Command',
    'notable' => 'Genome::Notable::Command',
    'population-group' => 'Genome::PopulationGroup::Command',
    'processing-profile' => 'Genome::ProcessingProfile::Command',
    'project' => 'Genome::Project::Command',
    'project-part' => 'Genome::ProjectPart::Command',
    'report' => 'Genome::Report::Command',
    'sample' => 'Genome::Sample::Command',
    'subject' => 'Genome::Subject::Command',
    'sys' => 'Genome::Sys::Command',
    'task' => 'Genome::Task::Command',
    'taxon' => 'Genome::Taxon::Command',
    'tools' => 'Genome::Model::Tools',
    'db' => 'Genome::Db',
);

for my $class (values %command_map) {
    eval "use $class";
    die $@ if $@;
}

$Genome::Command::SUB_COMMAND_MAPPING = \%command_map;

1;
