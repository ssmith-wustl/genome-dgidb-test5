package Genome::Model::MetagenomicComposition16s::Command::CopyFiles; 

use strict;
use warnings;

use Genome;

require File::Basename;
require File::Copy;

class Genome::Model::MetagenomicComposition16s::Command::CopyFiles {
    is => 'Genome::Model::MetagenomicComposition16s::Command',
    has => [
        file_type => {
            is => 'Text',
            doc => 'Type of file to copy/list.',
            valid_values => [qw/ oriented_fasta processed_fasta classification /],
        },
        destination => {
            is => 'Text',
            is_optional => 1,
            doc => 'The directory to copy the files.',
        },
        #rename_to => {
        #    is => 'Text',
        #    is_optional => 1,
        #    doc => 'The pattern to rename the file when copying.',
        #},
        force => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'If destination files exist, overwrite.',
        },
        list => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'List (don\'t copy) the builds\' files',
        },
    ],
};

sub help_brief { 
    return 'List and copy files for MC16s models';
}

sub help_detail {
    return <<HELP;
    Copies files from builds (for each amplicon set) into a destination directory, optionally renaming them as it goes.

    To just see the files, use --list. 
    Use --force to overwrite existing files.

    This command is backward compatible for amplicon assembly builds:
     oriented fasta is the same
     processed fasta in MC16s is 'assembly' fasta in amplicon assembly
     classification file does not exist for amplicon assembly

HELP
}

sub execute {
    my $self = shift;

    my $method;
    if ( $self->list ) {
        # list
        $method = '_list';
    }
    else {
        # copy
        Genome::Sys->validate_existing_directory( $self->destination )
            or return;
        $method = '_copy';
    }

    my $file_method = $self->file_type.'_file';
    my @builds = $self->_builds # errors in this method
        or return;
    for my $build ( @builds ) {
        # aa backward compatibility
        if ( $build->type_name eq 'metagenomic composition 16s' ) {
            my @amplicon_sets = $build->amplicon_sets;
            unless ( @amplicon_sets ) {
                $self->error_message("No amplicon sets for ".$build->description);
                return;
            }
            for my $amplicon_set ( @amplicon_sets ) {
                $self->$method($amplicon_set, $file_method)
                    or return;
            }
        }
        elsif ( $build->type_name eq 'amplicon assembly' ) {
            $self->$method($build, $file_method) # the build acts as amplicon set
                or return;
        }
        else {
            die "Incompatible build type: ".$build->type_name;
        }
    }

    return 1;
}

sub _list {
    my ($self, $amplicon_set, $file_method) = @_;

    return print $amplicon_set->$file_method."\n";
}

sub _copy {
    my ($self, $amplicon_set, $file_method) = @_;

    my $target = $amplicon_set->$file_method;
    my $base_name = File::Basename::basename($target);
    my $dest = $self->destination.'/'.$base_name;

    if ( -e $dest ) {
        if ( $self->force ) {
            unlink $dest;
        }
        else {
            $self->error_message("Can't copy to $dest because it exists. Use --force option to overwrite existing files.");
            return;
        }
    }

    unless ( File::Copy::copy($target, $dest) ) {
        $self->error_message("Can't copy $target\nto $dest\nError: $!");
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
