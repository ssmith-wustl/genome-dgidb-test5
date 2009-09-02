package Genome::Model::Build::AmpliconAssembly;

use strict;
use warnings;

use Genome;

require Genome::Model::Build::AmpliconAssembly::Amplicon;

class Genome::Model::Build::AmpliconAssembly {
    is => 'Genome::Model::Build',
    has => [
    map( { $_ => { via => 'amplicon_assembly' } } Genome::AmpliconAssembly->helpful_methods ),
    ],
};

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->model->type_name eq 'amplicon assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an amplicon assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    mkdir $self->data_directory unless -d $self->data_directory;
    
    $self->create_directory_structure
        or return;

    return $self;
}

#< AA >#
sub amplicon_assembly {
    my $self = shift;

    unless ( $self->{_amplicon_assembly} ) {
        $self->{_amplicon_assembly} = Genome::AmpliconAssembly->create(
            directory => $self->data_directory,
            sequencing_center => $self->model->sequencing_center,
            sequencing_platform => $self->model->sequencing_platform,
            assembler => $self->model->assembler,
            subject_name => $self->model->subject_name,
        );
    }

    return $self->{_amplicon_assembly};
}

#< INTR DATA >#
sub link_instrument_data {
    my ($self, $instrument_data) = @_;

    unless ( $instrument_data ) {
        $self->error_message("No instument data to link");
        return;
    }

    my $chromat_dir = $self->chromat_dir;
    my $instrument_data_dir = $instrument_data->resolve_full_path;
    my $dh = Genome::Utility::FileSystem->open_directory($instrument_data_dir)
        or return;

    my $cnt = 0;
    while ( my $trace = $dh->read ) {
        next if $trace =~ m#^\.#;
        $cnt++;
        my $target = sprintf('%s/%s', $instrument_data_dir, $trace);
        my $link = sprintf('%s/%s', $chromat_dir, $trace);
        next if -e $link;
        Genome::Utility::FileSystem->create_symlink($target, $link)
            or return;
    }

    unless ( $cnt ) {
        $self->error_message("No traces found in instrument data directory ($instrument_data_dir)");
    }

    return $cnt;
}

#< Reports >#
sub get_stats_report {
    my $self = shift;

    my $report = $self->get_report('Stats');

    return $report if $report;

    $report = $self->get_report('Assembly Stats'); #old name

    unless ( $report ) {
        $self->error_message("No stats report found for build: ".$self->id);
        return;
    }

    return $report;
}

############################################
#< THIS IS OLD...DON'T WANNA (RE)MOVE YET >#
sub amplicons_and_headers { 
    my $self = shift;

    my $amplicons = $self->amplicons
        or return;

    my $header_generator= sub{
        return sprintf(">%s\n", $_[0]);
    };
    if ( $self->name =~ /ocean/i ) {
        my @counters = (qw/ -1 Z Z /);
        $header_generator = sub{
            if ( $counters[2] eq '9' ) {
                $counters[2] = 'A';
            }
            elsif ( $counters[2] eq 'Z' ) {
                $counters[2] = '0';
                if ( $counters[1] eq '9' ) {
                    $counters[1] = 'A';
                }
                elsif ( $counters[1] eq 'Z' ) {
                    $counters[1] = '0';
                    $counters[0]++; # Hopefully we won't go over Z
                }
                else {
                    $counters[1]++;
                }
            }
            else {
                $counters[2]++;
            }

            return sprintf(">%s%s%s%s\n", $self->model->subject_name, @counters);
        };
    }

    my %amplicons_and_headers;
    for my $amplicon ( sort { $a cmp $b } keys %$amplicons ) {
        $amplicons_and_headers{$amplicon} = $header_generator->($amplicon);
    }

    return \%amplicons_and_headers;
}

1;

#$HeadURL$
#$Id$
