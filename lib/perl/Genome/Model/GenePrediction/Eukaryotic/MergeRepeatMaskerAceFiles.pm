package Genome::Model::GenePrediction::Eukaryotic::MergeRepeatMaskerAceFiles;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::GenePrediction::Eukaryotic::MergeRepeatMaskerAceFiles { 
    is => 'Command',
    has => [
        ace_files => {
            is => 'ARRAY',
            is_input => 1,
            doc => 'Array of ace files that need to be merged',
        },
        merged_ace_file => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Location of merged ace file',
        },
    ],
    has_optional => [
        remove_non_unique => {
            is => 'Boolean',
            default => 1,
            doc => 'If set, non-unique input ace files are removed from list',
        },
        remove_input_ace_files => {
            is => 'Boolean',
            default => 1,
            doc => 'If set, input ace files are removed after merging completes successfully',
        },
    ],
};

sub execute {
    my $self = shift;
    
    my @ace_files = @{$self->ace_files};
    @ace_files = grep { -e $_ and -s $_ } @ace_files;
    @ace_files = $self->uniqify(@ace_files) if $self->remove_non_unique;
    
    if (@ace_files) {
        $self->status_message("Concatenating ace files into " . $self->merged_ace_file . "\n" . join("\n", @ace_files));
        my $rv = Genome::Sys->cat(
            input_files => \@ace_files,
            output_file => $self->merged_ace_file,
        );
        unless ($rv) {
            Carp::confess "Could not merge ace files!";
        }

        if ($self->remove_input_ace_files) {
            $self->status_message("Removing input ace files " . join(",", @ace_files));
            my @unremoved = $self->remove_files(@ace_files);
            if (@unremoved) {
                Carp::confess "Could not remove some input ace files: " . join(',', @unremoved);
            }

            $self->status_message("Done removing input ace files!");
        }

        $self->status_message("Merging done!");
    }
    else {
        $self->status_message("No ace files to merge, skipping!");
    }

    return 1;
}

sub uniqify {
    my $self = shift;
    my @list = @_;
    return unless @list;
    my %unique;
    for my $item (@list) {
        $unique{$item} = 1;
    }
    return keys %unique;
}

sub remove_files { 
    my $self = shift;
    my @files = @_;

    my @unremoved;
    for my $file (@files) {
        my $rv = unlink $file;
        push @unremoved, $file unless $rv;
    }

    return @unremoved;
}

1;

