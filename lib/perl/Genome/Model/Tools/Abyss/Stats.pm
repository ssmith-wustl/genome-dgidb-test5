package Genome::Model::Tools::Abyss::Stats;

use Genome;

class Genome::Model::Tools::Abyss::Stats {
    is => 'Genome::Model::Tools::Assembly::Stats',
    has => [
	assembly_directory => {
	    type => 'Text',
	    is_optional => 1,
	    doc => "path to assembly",
	},
	output_file => {
	    type => 'Text',
	    is_optional => 1,
	    doc => "path to write stats to",
	},
	no_print_to_screen => {
	    is => 'Boolean',
	    is_optional => 1,
	    default_value => 0,
	    doc => 'Prevent printing of stats to screen',
	},
    ],
};

sub execute {
    my ($self) = @_;

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir in assembly directory");
	return;
    }

    my $output_file = $self->output_file || $self->assembly_directory . "/edit_dir/stats.txt";
    unlink $output_file;
    my $fh = Genome::Sys->open_file_for_writing($output_file) ||
	die "Failed to open output file $output_file for writing.";
    $fh->close;



    return 1;
}

1;
