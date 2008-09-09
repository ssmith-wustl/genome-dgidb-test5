package Genome::Model::Tools::Maq::MapSplit;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::Maq::MapSplit {
    is => 'Genome::Model::Tools::Maq',
    has => [
            map_file => {
                         doc => 'The input map file to split by seqid',
                         is => 'String',
                     },
            submap_directory => {
                                 doc => 'The directory to dump submap files after split',
                                 is => 'String',
                             },
            reference_names => {
                             doc => "a list of expected ref names to find.  any additional ref names will be grouped into 'other'",
                             is => 'ArrayRef',
                         }
        ],
};

sub help_brief {
    'a tool for splitting whole genome map files by seqid';
}

sub help_detail {
    return <<"EOS"
whole-genome map files can be split into submaps for parallel execution
of commands on a seqid or chromosome granularity.
this tool splits a map file into submaps based on the target seqid
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless (-s $self->map_file) {
        $self->error_message('Map file '. $self->map_file .' not found or has zero size.');
        return;
    }
    unless (-d $self->submap_directory) {
        $self->error_message('Submap directory '. $self->submap_directory .' not found or is not a directory.');
        return;
    }

    my @names;
    # Grab the reference names
    # If this is being called from code
    if (ref($self->reference_names)) {
        @names = @{$self->reference_names};
    }
    # Otherwise, its being called from command line
    else {
        @names = split(',',$self->reference_names);
    }
    
    unless (@names) {
        $self->error_message('No reference names specified!');
        return;
    }
    
    # If 'other' is not present, add it and re-set reference names
    unless (grep { $_ eq 'other' } @names) {
        push @names, 'other';
        $self->reference_names(\@names);
    }

    return $self;
}

sub execute {
    my $self = shift;
    require Genome::Model::Tools::Maq::Map::Reader;
    require Genome::Model::Tools::Maq::Map::Writer;

    my $map_reader = Genome::Model::Tools::Maq::Map::Reader->new;
    $map_reader->open($self->map_file);

    my $header = $map_reader->read_header;

    my @ref_names = @{$$header{'ref_name'}};
    unless (scalar(@ref_names) eq $$header{'n_ref'}) {
        $self->error_message('The ref_names and n_ref are not equal in header for map file '. $self->map_file);
        return;
    }
    # maq sets n_mapped_reads to zero in submap headers
    # all other fields are the same in submap headers
    $$header{'n_mapped_reads'} = 0;

    # Initialize all the writers needed for split
    my %writers;
    for my $expected_ref_name (@{$self->reference_names}) {
        if ($expected_ref_name eq 'other') {
            $writers{'other'} = $self->create_writer('other',$header);
            next;
        }
        for my $ref_name (@ref_names) {
            if ($expected_ref_name eq $ref_name) {
                $writers{$expected_ref_name} = $self->create_writer($expected_ref_name,$header);
                last;
            }
        }
        unless (defined $writers{$expected_ref_name}) {
            die('Expected reference name '. $expected_ref_name .' not found in header for map file '. $self->map_file);
        }
    }

    # split the map file into it's appropriate writers
    while(my $record = $map_reader->get_next) {
        my $ref_name = $ref_names[$$record{'seqid'}];
        if ($writers{$ref_name}) {
            $writers{$ref_name}->write_record($record);
        } else {
            $writers{'other'}->write_record($record);
        }
    }
    $map_reader->close;

    # close all the writers we created
    for (keys %writers) {
        $writers{$_}->close;
        push @{$self->{_output_files}}, $writers{$_}->{file_name};
    }
    return 1;
}

sub output_files {
    return @{$_[0]->{_output_files}};
}

sub create_writer {
    my ($self,$ref_name,$header) = @_;
    my $map_file = $self->submap_directory .'/'. $ref_name .'.map';
    my $map_writer = Genome::Model::Tools::Maq::Map::Writer->new(file_name => $map_file);
    $map_writer->open($map_file);
    $map_writer->write_header($header);
    return $map_writer;
}

1;
