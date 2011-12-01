package Genome::Model::Tools::Soap::GapCloser;

use strict;
use warnings;

use Genome;
use File::Basename;

class  Genome::Model::Tools::Soap::GapCloser {
    is => 'Genome::Model::Tools::Soap::Base',
    has => [
        version => {
            is => 'String',
            doc => 'Version of GapCloser',
            default_value => 1.10, # only one, and it's deployed to /gsc/scripts/bin
            valid_values => [qw/ 1.10 /],
        },
        assembly_directory => {
            is => 'Text',
            is_optional => 1,
            doc => 'Assembly directory to derive input/output files from.',
        },
        scaffold_sequence_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'SOAP generated scafSeq file. Default is named *.scafSeq in the assembly directory',
        },
        config_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Config file used for the SOAP assembly. Default is named "config_file" in the assembly directory',
        },
        output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'GapCloser output fasta file. Default is named "gapfill" in the assembly directory',
        },
        overlap_length => {
            is => 'Number',
            doc => 'Overlap length/K value. Typical default is 25. Max is 31.',
        },
    ],
};

sub help_brief {
    'GapCloser: close dem gaps!';
}

sub help_detail {
    return <<HELP;
HELP
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    my @input_file_methods = (qw/ scaffold_sequence_file config_file /);

    my $overlap_length = $self->overlap_length;
    if ( $overlap_length > 31 or $overlap_length < 1 ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ overlap_length /],
            desc => "The overlap_length ($overlap_length) must be an integer between 1 and 31!",
        );
    }

    if ( $self->assembly_directory ) {
        if ( not -d $self->assembly_directory ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ assembly_directory /],
                desc => 'The assembly_directory is not a directory!',
            );
            return @errors;
        }
        if ( my @defined_inputs = grep { defined $self->$_ } @input_file_methods ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ assembly_directory /],
                desc => "Gave inputs (@defined_inputs) and assembly_directory. Please only give assembly_directory or the inputs files!",
            );
            return @errors;
        }
        $self->scaffold_sequence_file( $self->assembly_scaffold_sequence_file );
        $self->config_file( $self->scaffold_sequence_file );
        $self->output_file( $self->assembly_directory.'/gapfill' );
    }
    elsif ( not $self->output_file ) { 
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ output_file /],
            desc => 'No output_file given and no assembly_directory given to determine the output file!',
        );
    }

    for my $input_file_method ( @input_file_methods ) {
        my $file = $self->$input_file_method;
        if ( not $file ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [ $input_file_method ],
                desc => "The $input_file_method is required! This can be resolved from the assmbly directory or passed in.",
            );
            return @errors;
        }
        if ( not -s $file ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [ $input_file_method ],
                desc => "The $input_file_method ($file) does not have any size!",
            );
            return @errors;
        }
    }

    return @errors;
}

sub execute {
    my $self = shift;

    $self->status_message('SOAP GapCloser...');

    unlink $self->output_file;

    my $cmd = sprintf(
        'GapCloser -o %s -a %s -b %s -p %s',
        $self->output_file,
        $self->scaffold_sequence_file,
        $self->config_file,
        $self->overlap_length,
    );

    #my $rv = eval{ Genome::Sys->shell_cmd(cmd => $cmd); };
    my $rv = print "$cmd\n";
    if ( not $rv ) {
        $self->error_message('GapCloser shell command failed!');
        return;
    }

    $self->status_message('SOAP GapCloser...DONE');

    return 1;
}

1;

