package Genome::Model::Command::MetaGenomicComposition::CollateFastaForProcessingProfile;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use Genome::Utility::IO::SeparatedValueReader;

class Genome::Model::Command::MetaGenomicComposition::CollateFastaForProcessingProfile {
    #is => 'Genome::Model::Command::MetaGenomicComposition::CollateFasta',
    is => 'Command',
    has => [
    processing_profile_name => {
        is => 'String', 
        doc => 'Processing profile name to get models',
    },
    directory => {
        is => 'DirectoryWrite',
        doc => 'Directory to fasta and qual files for processing profile.'
    },
    map {
        $_ => {
            type => 'Boolean',
            is_optional => 1,
            default => 1,
            doc => 'assemblies',
        }
    } fasta_and_qual_types(),
    ], 
};

sub help_brief {
    "MGC get all fastas" 
}

sub help_detail {                        
    return <<"EOS"
EOS
}

sub fasta_and_qual_types {
    return (qw/ assembled pre_process_input assembly_input /);
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unlink $self->fasta_file if -e $self->fasta_file;
    unlink $self->qual_file if -e $self->qual_file;

    return $self;
}

sub DESTROY { 
    my $self = shift;

    $self->_close_output_fhs;
    $self->SUPER::DESTROY;

    return 1;
}

sub execute {
    my $self = shift;

    my @models = Genome::Model->get(processing_profile_name => $self->processing_profile_name);
    unless ( @models ) {
        $self->error_message(
            sprintf('No models for processing profile name (%s)', $self->processing_profile_name) 
        );
        return;
    }

    $self->_open_output_fhs
        or return;

    my %metrics;
    for my $model ( @models ) {
        $self->status_message( sprintf('<=== Grabbing Fasta and Qual for %s ===>', $model->name) );
        for my $type ( $self->fasta_and_qual_types ) {
            next unless $self->$type;
            $self->_add_fasta_and_qual($model, $type)
                or return;
        }
    }

    return $self->_close_output_fhs;
}

sub _open_output_fhs {
    my $self = shift;

    my $pp_name = $self->processing_profile_name;
    $pp_name =~ s/ /\_/g;

    for my $type ( $self->fasta_and_qual_types ) {
        next unless $self->$type;
        my $fasta_file = sprintf('%s/%s.%s.fasta', $self->directory, $pp_name, $type);
        unlink $fasta_file if -e $fasta_file;
        my $fasta_fh = IO::File->new($fasta_file, 'w');
        unless ( $fasta_fh ) {
            $self->error_message("Can't open file ($fasta_file): $!");
            return;
        }
        $self->{ sprintf('_%s_fasta_fh', $type) } = $fasta_fh;

        my $qual_file = $fasta_file . '.qual';
        unlink $qual_file if -e $qual_file;
        my $qual_fh = IO::File->new($qual_file, 'w');
        unless ( $qual_fh ) {
            $self->error_message("Can't open file ($qual_file): $!");
            return;
        }
        $self->{ sprintf('_%s_qual_fh', $type) } = $qual_fh;
    }

    return 1;
}

sub _close_output_fhs {
    my $self = shift;

    for my $type ( $self->fasta_and_qual_types ) {
        next unless $self->$type;
        $self->{ sprintf('_%s_fasta_fh', $type) }->close if $self->{ sprintf('_%s_fasta_fh', $type) };
        $self->{ sprintf('_%s_qual_fh', $type) }->close if $self->{ sprintf('_%s_qual_fh', $type) };
    }

    return 1;
}

sub _add_fasta_and_qual {
    my ($self, $model, $type) = @_;

    # FASTA
    my $fasta_file_method = sprintf('all_%s_fasta', $type);
    my $fasta_file = $model->$fasta_file_method;
    unless ( -e $fasta_file ) {
        $self->error_message( sprintf('No fasta file for type ($type) for model (%s)', $model->name) );
        return;
    }
    my $fasta_fh = IO::File->new($fasta_file, 'r');
    unless ( $fasta_fh ) { 
        $self->error_mesage("Can't open fasta file ($fasta_file) for reading");
        return;
    }
    my $fasta_fh_key = sprintf('%s_fasta_fh', $type);
    while ( my $line = $fasta_fh->getline ) {
        $self->{$fasta_fh_key}->print($line);
    }
    $self->{$fasta_fh_key}->print("\n");

    #QUAL
    my $qual_file = sprintf('%s.qual', $fasta_file);
    unless ( -e $qual_file ) {
        $self->error_message( sprintf('No fasta file for type ($type) for model (%s)', $model->name) );
        return;
    }
    my $qual_fh = IO::File->new("< $qual_file");
    unless ( $qual_fh ) { 
        $self->error_mesage("Can't open fasta file ($qual_file) for reading");
        return;
    }
    my $qual_fh_key = sprintf('%s_fasta_fh', $type);
    while ( my $line = $qual_fh->getline ) {
        $self->{$qual_fh_key}->print($line);
    }
    $self->{$qual_fh_key}->print("\n");

    return 1;
}

1;

#$HeadURL$
#$Id$
