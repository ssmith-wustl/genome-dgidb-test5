package Genome::Model::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use File::Grep 'fgrep';
require Genome::Consed::Directory;
require Genome::Model::AmpliconAssembly::Amplicon;
require Genome::ProcessingProfile::AmpliconAssembly;
use POSIX 'floor';

class Genome::Model::AmpliconAssembly {
    is => 'Genome::Model',
    has => [
    map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::AmpliconAssembly->params_for_class
    ),
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    mkdir $self->data_directory unless -d $self->data_directory;
    
    $self->consed_directory->create_consed_directory_structure
        or return;

    return $self;
}

sub consed_directory {
    my $self = shift;

    unless ( $self->{_consed_directory} ) {
        $self->{_consed_directory} = Genome::Consed::Directory->create(directory => $self->data_directory);
    }

    return $self->{_consed_directory};
}

#< Misc >#
sub build_subclass_name {
    return 'amplicon-assembly';
}

#< Files & Dirs >#
sub create_consed_directory_structure {
    return $_[0]->consed_directory->create_consed_directory_structure;
}

sub edit_dir {
    return $_[0]->consed_directory->edit_dir;
}
    
sub phd_dir {
    return $_[0]->consed_directory->phd_dir;
}
    
sub chromat_dir {
    return $_[0]->consed_directory->chromat_dir;
}
    
sub _fasta_file_name {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.%s.fasta',
        $self->data_directory,
        $self->subject_name,
        $type,
    );
}

sub reads_fasta {
    return _fasta_file_name(@_, 'reads');
}

sub processed_fasta {
    return _fasta_file_name(@_, 'processed');
}

sub assembly_fasta {
    return _fasta_file_name(@_, 'assembly');
}

sub orientation_confirmed_fasta {
    return _fasta_file_name(@_, 'assembly.confirmed');
}

sub orientation_unconfirmed_fasta {
    return _fasta_file_name(@_, 'assembly.unconfirmed');
}

sub _classification_file_name {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.%s',
        $self->data_directory,
        $self->subject_name,
        $type,
    );
}

sub rdp_file {
    return _classification_file_name(@_, 'rdp');
}

#< DEPRECATED 
sub all_assembled_fasta {
    return _fasta_file_name(@_, 'assembled');
}

sub all_pre_processing_fasta {
    return _fasta_file_name(@_, 'pre_process_input');
}

sub all_assembly_input_fasta {
    return _fasta_file_name(@_, 'assembly_input');
}
#>#

sub metrics_file {
    my $self = shift;

    return sprintf('%s/%s.metrics.txt', $self->data_directory, $self->subject_name);
}

sub quality_histogram_file {
    my $self = shift;

    return sprintf('%s/%s.histogram.png', $self->data_directory, $self->subject_name);
}

#< DETERMINING AMPLICONS >#
sub amplicons {
    my $self = shift;

    my $method = sprintf('_determine_amplicons_in_chromat_dir_%s', $self->sequencing_center);
    my $amplicons = $self->$method;
    unless ( $amplicons and %$amplicons ) {
        $self->error_message(
            sprintf('No amplicons found in chromat_dir of model (%s)', $self->name) 
        );
        return;
    }

    return $amplicons;
}

sub get_amplicons {
    my $self = shift;

    my $amplicons = $self->amplicons
        or return;

    my @amplicons;
    my $edit_dir = $self->edit_dir;
    for my $name ( keys %$amplicons ) {
        push @amplicons, Genome::Model::AmpliconAssembly::Amplicon->new(
            name => $name,
            reads => $amplicons->{$name},
            directory => $edit_dir,
        );
    }

    return \@amplicons;

}

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

            return sprintf(">%s%s%s%s\n", $self->subject_name, @counters);
        };
    }

    my %amplicons_and_headers;
    for my $amplicon ( sort { $a cmp $b } keys %$amplicons ) {
        $amplicons_and_headers{$amplicon} = $header_generator->($amplicon);
    }

    return \%amplicons_and_headers;
}

sub _determine_amplicons_in_chromat_dir_gsc {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %amplicons;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz##;
        $scf =~ /^(.+)\.[bg]\d+$/
            or next;
        push @{$amplicons{$1}}, $scf;
    }
    $dh->close;

    return \%amplicons;
}

sub _determine_amplicons_in_chromat_dir_broad {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %amplicons;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz$##;
        my $amplicon = $scf;
        $amplicon =~ s#\.T\d+$##;
        $amplicon =~ s#[FR](\w\d\d?)$#\_$1#; # or next;

        push @{$amplicons{$amplicon}}, $scf;
    }
    
    return  \%amplicons;
}

1;

#$HeadURL$
#$Id$
