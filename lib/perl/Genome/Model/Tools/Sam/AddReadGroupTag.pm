package Genome::Model::Tools::Sam::AddReadGroupTag;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::AddReadGroupTag {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        input_file => {
            is  => 'String',
            doc => 'The SAM file to add a read group and program group tag to.',
        },
        output_file => {
            is  => 'String',
            doc => 'The resulting file',
        },
        read_group_tag => {
            is  => 'String',
            doc => 'The value which will be added to every record of the input file in the RG tag and PG tag.',
        },
    ],
};

sub help_brief {
    'Tool to add a read group tag to SAM files.';
}

sub help_detail {
    return <<EOS
    Tool to add a read group tag to SAM files.
EOS
}

sub execute {
    my $self = shift;

    my $input_file = $self->input_file;
    my $output_file = $self->output_file; 
    my $read_group_tag = $self->read_group_tag; 
    
    $self->status_message("Attempting to add read group tag: $read_group_tag to $input_file.  Result file will be: $output_file");
   
    if (-s $output_file )  {
       $self->error_message("The target file already exists at: $output_file . Please remove this file and rerun to generate a new merged file.");
       return;
    }
    
    my $now = UR::Time->now;
    $self->status_message(">>> Beginning add read tag at $now");
    
    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output_file);
    my $input_fh = Genome::Utility::FileSystem->open_file_for_reading($input_file);
    
        while (my $line = $input_fh->getline) {
                my $first_char = substr($line, 0, 1);
                if ( $first_char ne '@') {
                    $line =~ m/((\S*\s){11})(.*)$/;
                    my $front = $1;
                    my $back = $3;
                    chomp $front;
		    if (defined $back) {
			chomp $back;
		    }
                    if ($back eq "") {
                        print $output_fh $front."\tRG:Z:$read_group_tag\tPG:Z:$read_group_tag\n";
                    } else {
                        print $output_fh $front."RG:Z:$read_group_tag\tPG:Z:$read_group_tag\t".$back."\n";
                    }
                } else {
                    print $output_fh $line;
                }    
            }

    $output_fh->close;
    $now = UR::Time->now;
    $self->status_message("<<< Completed add read tag at $now.");
 
    return 1;
}


1;
