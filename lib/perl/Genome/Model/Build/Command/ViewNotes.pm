package Genome::Model::Build::Command::ViewNotes;

class Genome::Model::Build::Command::ViewNotes {
    is => 'Genome::Command::Base',
    has => [
        builds => {
            is => 'Genome::Model::Build',
            is_many => 1,
            shell_args_position => 1,
            doc => 'builds resolved by Genome::Command::Base',
        },
        note_type => {
            is => 'Text',
            is_optional => 1,
            doc => 'note type (e.g. the header) to view',
        },
    ],
    doc => 'view notes that have been set on builds',
};

sub help_detail {
    return <<EOS
This command can be used to view the notes that have been added to a build.

For example this can be used to see why a build was not startable:
    genome model build view-notes --note-type=Unstartable <build_id>
EOS
}

sub execute {
    my $self = shift;

    my %note_params;
    $note_params{header_text} = $self->note_type if $self->note_type;

    my @builds = $self->builds;
    for my $build (@builds) {
        print "\n" . 'Notes for ' . $build->__display_name__ . "\n";
        my @notes = $build->notes(%note_params);
        for my $note (@notes) {
            print $note->header_text . ' by ' . $note->editor_id . ' on ' . $note->entry_date . ":\n";
            my @body_lines = split("\n", $note->body_text);
            print '> ' . join("\n> ", @body_lines) . "\n";
        }
        print "\n";
    }
    return 1;
}
