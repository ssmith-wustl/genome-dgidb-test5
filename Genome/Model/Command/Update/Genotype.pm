
package Genome::Model::Command::Update::Genotype;

use strict;
use warnings;

use UR;
use Genome::Model::Command::IterateOverRefSeq;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::IterateOverRefSeq',
    has => [
        result      => { type => 'Array', 
                        doc => 'If set, results will be stored here instead of printing to STDOUT.' },
        bases_file  => { type => 'String',
                        doc => 'The pathname of the binary file containing prb values' },
        bases_fh    => { type => 'IO::File',
                        doc => 'The file handle to the binary file containing prb values' },
    ],
);

sub help_brief {
    "generate base-by-base consensus genotype"
}

sub help_synopsis {
    return <<"EOS"

???

Launch a genotyping algorithm.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve consensus's.

Subclasses will implement different per-base consensus calling algorithms.  This module
should handle common consensus parameters, typically for handling the results. 

EOS
}

sub create {
    # UR::Object won't currently take a non-UR object as a property value during construction.
    # Until fixed, work around it for the file handle.
    my $class = shift;
    my (%params) = @_;
    my $bases_fh = delete $params{bases_fh};
    my $self = $class->SUPER::create(%params);
    return unless $self;
    $self->bases_fh($bases_fh);
    return $self;
}

sub execute {
    my ($self) = @_;

    if ($self->bases_file and not $self->bases_fh) {
        my $bases_fh = IO::File->new($self->bases_file);   # Ugly hack until _examine_position can be called as a method
        unless ($bases_fh) {
            $self->error_message("Can't open bases file: $!");
            return;
        }
        $self->bases_fh($bases_fh);
    }

    unless($self->bases_fh) {
        $self->error_message("A bases file must be specified!");
        return;
    }        

    $self->SUPER::execute(
        iterator_method => 'foreach_aligned_position',
        bases_fh        => $self->bases_fh,
    );
}

sub _print_result {
    my ($pos,$coverage) = @_;
    print "$pos\t$coverage\n";
}

1;

