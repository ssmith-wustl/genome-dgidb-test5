package Genome::Model::Tools::Sx::BamReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx::BamReader {
    is => 'Genome::Model::Tools::Sx::SamReader',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $file = $self->file; 
    if ( not $file ) {
        $self->error_message("File is required");
        return;
    }
    my $cmd = 'samtools view '.$file.' |';
    my $fh = IO::File->new($cmd);
    if ( not $fh ) {
        $self->error_message("Failed to open samtools command with file ($file): $@");
        return;
    }
    $self->{_file} = $fh;

    return $self;
}

1;

