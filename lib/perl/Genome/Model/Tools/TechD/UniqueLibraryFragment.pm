package Genome::Model::Tools::TechD::UniqueLibraryFragment;

class Genome::Model::Tools::TechD::UniqueLibraryFragment {
    is => 'Genome::Model::Tools::TechD',
    has => [
        seq_id => { },
    ]
};

sub execute {
    my $self = shift;
    my $sls = GSC::RunLaneSolexa->get($self->seq_id);
    unless ($sls) {
        die('Failed to find SolexaLaneSummary for seq_id '. $self->seq_id);
    }
    print $sls->unique_library_fragment_percent ."\n";
    return 1;
}

