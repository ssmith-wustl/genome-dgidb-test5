package Genome::Model::Tools::Annotate::Adaptor::BedToAnnotation;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Annotate::Adaptor::BedToAnnotation{
    is => ['Genome::Model::Tools::Annotate'],
    has => [
        bed_file => {
            is => 'Path',
            is_input => '1',
            is_optional => '0',
            doc => 'BED4 file to convert to annotator variant format',
        },
        output_file => {
            is => 'Path',
            is_input => '1',
            is_optional => '0',
            doc => 'Filepath to output file',
        },
    ],
};

sub execute{
    my $self = shift;

    unless(-s $self->bed_file){
       $self->error_message("Bed file " . $self->bed_file . " has no size, exiting") and die; 
    }

    my $output = IO::File->new($self->output_file, "w");
    unless ($output){
       $self->error_message("Could not open output file, exiting") and die; 
    }
    
    my @columns = qw/ chromosome start stop reference variant /;
    my $svr = Genome::Utility::IO::SeparatedValueReader->create(
        input => $self->bed_file,
        headers => \@columns,
        separator => "\t|\/",
        is_regex => 1,
        ignore_extra_columns => 1,
    );
    unless ($svr){
       $self->error_message("No separated value reader, exiting") and die; 
    }
    while (my $line = $svr->next){
        my $final = join("\t", $line->{'chromosome'}, $line->{'start'} + 1, $line->{'stop'}, $line->{'reference'}, $line->{'variant'});
        print $output $final . "\n";
    }

    $output->close;
    return 1;
}

1;
