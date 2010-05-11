package Genome::Model::Msi::Command::WriteChangesToBuild; 

use strict;
use warnings;

use IO::File;
use File::Basename;
use Workflow::Simple;

class Genome::Model::Msi::Command::WriteChangesToBuild {
    is => 'Command',
    has => [
        assembly_build_id => { 
            is => 'Number', 
            shell_args_position => 1,
            is_optional => 1,
            doc => 'the exact build of denovo assembly, imported assembly, or prior msi to examine' 
        },
        output_build_id => {    
            is => 'Number', 
            shell_args_position => 2,
            is_optional => 0,
            doc => 'the output build that the new assembly will be written to'
        }

    ],
        
    doc => 'identify possible merges in an assembly (usable in the merge command)'
};

sub execute {
    my $self = shift;
    
    $DB::single = 1;

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
    
    my $output_build_id = $self->output_build_id;

        
    unless ($output_build_id) {
        # still not set
        $self->error_message("No output build specified!");
        return;
    }


    if ($output_build_id =~ /\D/) {
        $self->error_message("The specified output build id is not a number!: $output_build_id");
        return;
    }
    
    my $output_build = Genome::Model::Build->get($output_build_id);
    unless ($output_build) {
        $self->error_message("failed to find a build with id $output_build_id!");    
        return;
    }
    
    $self->status_message("Found output  build " . $output_build->__display_name__ . " for model " . $output_build->model->__display_name__);

    # get the data directory, run the tool
    my $input_data_directory = $assembly_build->data_directory;
    my $input_edit_dir = $input_data_directory . "/edit_dir";
   
    # get the data directory, run the tool
    my $output_data_directory = $output_build->data_directory;
    my $output_edit_dir = $output_data_directory . "/edit_dir";
    if(! (-e $output_edit_dir)) { `mkdir -p $output_edit_dir`;}


    my @input_ace_files = `ls $input_edit_dir/*scaffold*.ace`;
    #filter out singleton acefiles
    @input_ace_files = grep { !/singleton/ } @input_ace_files;  
    
    $self->error_message( "There are no valid ace files in $output_edit_dir\n") and return unless (scalar @input_ace_files);  
    chomp @input_ace_files;
    
    my @output_ace_files;
    foreach(@input_ace_files)
    {
        my $ace_file_name = basename($_);
        push @output_ace_files, $output_edit_dir."/$ace_file_name";
    }
    my $input_ace_files = join ',',@input_ace_files;
    my $output_ace_files = join ',',@output_ace_files;
    
    my $w = Workflow::Operation->create(
        name => 'write changes to directory',
        operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Assembly::WriteChangesToDirectory'),
    );
    
    $w->parallel_by('index');
    
    #$w->log_dir('/gscmnt/936/info/jschindl/MISCEL/wflogs');
    
    $w->validate;
    if(!$w->is_valid)
    {
        $self->error_message("There was an error while validating merge detection workflow.\n") and return;
    }
    my @index;my $i=0;
    @index = map { $i++; } @input_ace_files;  
    my $result = Workflow::Simple::run_workflow_lsf(
        $w,
        index => \@index,
        'input_ace_files' => $input_ace_files,        
        'output_ace_files' => $output_ace_files,
    );
    
    unless($result)
    {
        # is this bad?
        foreach my $error (@Workflow::Simple::ERROR) {

            $self->error_message( join("\t", $error->dispatch_identifier(),
                                             $error->name(),
                                             $error->start_time(),
                                             $error->end_time(),
                                             $error->exit_code(),
                                            ) );

            $self->error_message($error->stdout());
            $self->error_message($error->stderr());

        }
        return;

    }
	return 1;
    


}
1;
