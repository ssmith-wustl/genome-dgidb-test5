package Genome::Model::Msi::Command::DoMerges; 

use strict;
use warnings;

use IO::File;

class Genome::Model::Msi::Command::DoMerges {
    is => 'Command',
    has => [
        assembly_build_id => { 
            is => 'Number', 
            shell_args_position => 1,
            is_optional => 1,
            doc => 'the exact build of denovo assembly, imported assembly, or prior msi to examine' 
        },
    ],
        
    doc => 'identify possible merges in an assembly (usable in the merge command)'
};

sub execute {
    my $self = shift;

    my $assembly_build_id = $self->assembly_build_id;
    unless ($assembly_build_id) {
        # is the user in a build directory?
        # TODO: infer the build from it..
        
        unless ($assembly_build_id) {
            # still not set
            $self->error_message("No assembly build specified, and unable to infer the assembly build from the current directory!");
            return;
        }
    }

    if ($assembly_build_id =~ /\D/) {
        $self->error_message("The specified assembly build id is not a number!: $assembly_build_id");
        return;
    }
    
    my $assembly_build = Genome::Model::Build->get($assembly_build_id);
    unless ($assembly_build) {
        $self->error_message("failed to find a build with id $assembly_build_id!");    
        return;
    }
    
    $self->status_message("Found assembly build " . $assembly_build->__display_name__ . " for model " . $assembly_build->model->__display_name__);

    # get the data directory, run the tool
    my $data_directory = $assembly_build->data_directory;
    my $edit_dir = $data_directory . "/edit_dir";

    my $merge_list = $edit_dir."/merge_list";

    return Genome::Model::Tools::Assembly::DoMerges->execute(merge_list => $merge_list, ace_directory => $edit_dir);

}
1;
