package Genome::Model::Tools::Blat::Cat;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::Blat::Cat {
    is => ['Genome::Model::Tools::Blat'],
    has => [
            psl_path => {
                         is => 'String',
                         is_input => 1,
                     },
            blat_output_path => {
                                 is => 'String',
                                 is_input => 1,
                             }
        ],
    has_many => [
                 psl_files => {
                               is => 'String',
                               is_input => 1,
                           },
                 output_files => {
                                  is => 'String',
                                  is_input => 1,
                              }
             ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "a tool to cat multiple blat outputs(psl and text aligner output) into one psl file and one text aligner output file",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt blat cat ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if (-s $self->psl_path) {
        $self->error_message('File already exists with size '. $self->psl_path);
        die;
    }
    if (-s $self->blat_output_path) {
        $self->error_message('File already exists with size '. $self->blat_output_path);
        die;
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $writer = Genome::Utility::PSL::Writer->create(file => $self->psl_path);
    unless ($writer) {
        $self->error_message('Could not create a writer for file '. $self->psl_path);
        return;
    }
    for my $in_file ($self->psl_files) {
        my $reader = Genome::Utility::PSL::Reader->create( file => $in_file);
        unless ($reader) {
            $self->error_message("Could not create a reader for file '$in_file'");
            return;
        }
        while (my $record = $reader->next) {
            $writer->write_record($record);
        }
        $reader->close;
    }
    $writer->close;


    my $output_writer = IO::File->new($self->blat_output_path,'w');
    unless ($output_writer) {
        $self->error_message('Could not creat filehandle for file '. $self->blat_output_path);
        return;
    }
    for my $in_file ($self->output_files) {
        my $reader = IO::File->new($in_file,'r');
        unless ($reader) {
            $self->error_message("Could not create a reader for file '$in_file'");
            return;
        }
        while (my $line = $reader->getline) {
            print $output_writer $line;
        }
        $reader->close;
    }
    $output_writer->close;

    return 1;
}



1;

