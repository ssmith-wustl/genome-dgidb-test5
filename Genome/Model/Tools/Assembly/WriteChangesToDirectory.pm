package Genome::Model::Tools::Assembly::WriteChangesToDirectory; 

use FindBin;
use Carp::Assert;
use Carp;
use Cwd;
use Utility;
use Genome::Assembly::Pcap::Ace;


class Genome::Model::Tools::Assembly::WriteChangesToDirectory {
    is => 'Command',
    has => [
        input_ace_files => { 
            is => 'String', 
            shell_args_position => 1,
            is_optional => 0,
            doc => 'a list of input ace files that we are updating',
            is_input => 1,
        },
        output_ace_files => {
            is => 'Number',
            shell_args_position => 2,
            is_optional => 0,
            is_input => 1,
            is_output => 1,
            doc => 'a list of output ace files that we are producing',
        },
        index =>  {
            is => 'Number',
            shell_args_position => 3,
            is_optional => 1,
            is_input => 1,
            doc => 'this is a private param that is used by workflow',
        },
    ],
    
    doc => 'writes an updated ace file using an input ace file and the changes stored in the mysql database (this is part of the 4th stage in the Msi pipeline)'
};


sub execute {
    my $self = shift;

    my $input_ace_files = $self->input_ace_files;
    my $output_ace_files = $self->output_ace_files;
    my $index = $self->index;
    
    my @input_ace_files = split /,/,$input_ace_files;
    my @output_ace_files = split /,/,$output_ace_files;
    
    $self->error_message("There is a mismatch between the number of input files given and the number of output files given, their needs to be a corresponding input for each output") and return unless (scalar @input_ace_files == scalar @output_ace_files);
    
    for(my $i=$index||0;$i<($index||scalar @input_ace_files);$i++)
    {
        my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $input_ace_files[$i], output_file => $output_ace_files[$i],using_db=>1,db_type => 'mysql');
        print "Updating $input_ace_files[$i] to $output_ace_files[$i]\n";
        $ao->write_file;   
    }

    return 1;
}

1;
