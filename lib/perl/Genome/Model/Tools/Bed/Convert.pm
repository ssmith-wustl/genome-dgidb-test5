package Genome::Model::Tools::Bed::Convert;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Bed::Convert {
    is => ['Command'],
    has_input => [
        source => {
            is => 'File',
            shell_args_position => 1,
            doc => 'The original file to convert to BED format',
        },
        output => {
            is => 'File',
            shell_args_position => 2,
            doc => 'Where to write the output BED file',
        },
    ],
    has_transient_optional => [
        _input_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the source variant file',
        },
        _output_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the output BED file',
        },
    ]
};

sub help_brief {
    "Tools to convert other variant formats to BED.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
  gmt bed convert ...
EOS
}

sub help_detail {                           
    return <<EOS
    This is a collection of small tools to take variant calls in various formats and convert them to a common BED format (using the first four columns).
EOS
}

sub execute {
    my $self = shift;
    
    unless($self->initialize_filehandles) {
        return;
    }
    
    my $retval = $self->process_source;
    
    $self->close_filehandles;
    
    return $retval;
}

sub initialize_filehandles {
    my $self = shift;
    
    if($self->_input_fh || $self->_output_fh) {
        return 1; #Already initialized
    }
    
    my $input = $self->source;
    my $output = $self->output;
    
    eval {
        my $input_fh = Genome::Utility::FileSystem->open_file_for_reading($input);
        my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output);
        
        $self->_input_fh($input_fh);
        $self->_output_fh($output_fh);
    };
    
    if($@) {
        $self->error_message('Failed to open file. ' . $@);
        $self->close_filehandles;
        return;
    }
    
    return 1;
}

sub close_filehandles {
    my $self = shift;
    
    my $input_fh = $self->_input_fh;
    close($input_fh) if $input_fh;
    
    my $output_fh = $self->_output_fh;
    close($output_fh) if $output_fh;
    
    return 1;
}

sub write_bed_line {
    my $self = shift;
    #start is zero-based index of first base in the event.
    #stop is zero-based index of first base *after* the event (e.g. for a SNV these will differ by one)
   
     #my ($chromosome, $start, $stop, $reference, $variant) = @_;
    my @values = @_;
    
    my $output_fh = $self->_output_fh;
    
    #my $name = join('/', $reference, $variant);
    my $name = join('/', $values[3], $values[4]);
    my @columns;
    for my $index (0..scalar(@values)){
        if($_==3){
            push @columns, $name;
        } elsif ($_==4){
        } else {
            push @columns, $values[$index];
        }
    }
    #print $output_fh join("\t", $chromosome, $start, $stop, $name), "\n";
    print $output_fh join("\t", @columns), "\n";
    
    return 1;
}

sub process_source {
    my $self = shift;

    $self->error_message('The process_source() method should be implemented by subclasses of this module.');
    return;
}

1;
