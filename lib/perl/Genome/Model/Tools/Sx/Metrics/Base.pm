package Genome::Model::Tools::Sx::Metrics::Base;

use strict;
use warnings;

use Genome;

use XML::LibXML;
use XML::LibXSLT;

class Genome::Model::Tools::Sx::Metrics::Base {
    is_abstract => 1,
};

sub calculate_metrics {
    return $_[0]->_metrics;
}

sub metrics {
    my $self = shift;
    my $metrics_class = $self->metrics_class;
    Carp::confess('No metrics class for '.$self->class) if not $metrics_class;
    my $metrics = $self->calculate_metrics;
    Carp::confess('No metrics for '.$self->id) if not $metrics;
    return $metrics_class->create(%$metrics);
}

sub metrics_class {
    my $self = shift;
    my $class = $self->class;
    $class =~ s/Genome::Model::Tools:://;
    return $class;
}

sub to_xml {
    my $self = shift;
    my $metrics = $self->metrics;
    my $view = UR::Object::View::Default::Xml->create(subject => $metrics);
    return $view->content;
}

sub transform_xml {
    my ($self, $xslt_file) = @_;

    Carp::confess('No xslt file given to transform xml!') if not $xslt_file;

    my $xml = XML::LibXML->new();
    my $xml_string = $xml->parse_string( $self->to_xml );
    my $style_doc = eval{ $xml->parse_file( $xslt_file ) };
    if ( $@ ) {
        Carp::confess("Error parsing xslt file ($xslt_file):\n$@");
    }

    my $xslt = XML::LibXSLT->new();
    my $stylesheet = eval { $xslt->parse_stylesheet($style_doc) };
    if ( $@ ) {
        Carp::confess("Error parsing stylesheet for xslt file ($xslt_file):\n$@");
    }

    my $transformed_xml = $stylesheet->transform($xml_string);
    return $stylesheet->output_string($transformed_xml);
}

sub transform_xml_to {
    my ($self, $type) = @_;
    my $xslt_file = $self->xslt_file_for($type);
    return $self->transform_xml($xslt_file);
}

sub xslt_file_for {
    my ($self, $type) = @_;

    Carp::confess('No type to get xslt file!') if not $type;
    
    my $genome_dir = Genome->get_base_directory_name;
    #my $inc_dir = substr($genome_dir, 0, -7); # rm Genome
    my $module = $self->class;
    $module =~ s/Genome:://;
    $module =~ s#::#/#g;
    my $xslt_file = sprintf(
        '%s/%s.%s.xsl',
        $genome_dir,
        $module,
        'txt',#$type
    );
    if ( not -s $xslt_file ) {
        Carp::confess("No xslt file ($xslt_file) for type ($type)");
    }

    return $xslt_file;
}

sub to_text {
    my $self = shift;
    my $metrics = $self->metrics;
    my $view = UR::Object::View::Default::Text->create(subject => $metrics);
    return $view->content;
}

sub from_file {
    my ($class, $file) = @_;

    if ( not $file ) {
        $class->error_message('No file given to create metrics from file');
        return;
    }

    if ( not -s $file ) {
        $class->error_message('Failed to read metrics from file. File ('.$file.') does not exist.');
        return;
    }

    my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
    if ( not $fh ) {
        $class->error_message("Failed to open file ($file)");
        return;
    }
    $fh->getline; # TODO get class from this line

    my %metrics;
    while ( my $line = $fh->getline ) {
        chomp $line;
        my ($key, $val) = split(': ', $line, 2);
        $key =~ s/^\s+//;
        $metrics{$key} = $val;
    }
    $fh->close;

    my $self = $class->create(_metrics => \%metrics);
    if ( not $self ) {
        $class->error_message("Failed to create metrics object from file ($file) with metrics: ".Data::Dumper::Dumper(\%metrics));
        return;
    }

    return $self;
}

sub to_file {
    my ($self, $file) = @_;

    if ( not $file ) {
        $self->error_message('No file given to create metrics from file');
        return;
    }

    unlink $file;
    my $fh = eval{ Genome::Sys->open_file_for_writing($file); };
    if ( not $fh ) {
        $self->error_message("Failed to open file ($file)");
        return;
    }
    $fh->print($self->to_text);
    $fh->close;

    return 1;
}

1;

