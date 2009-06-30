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

#< Contamination Screening >#
sub contamination_dir {
    return $_[0]->data_directory.'/contamination';
}

sub contamination_reads_dir {
    return $_[0]->contamination_dir.'/reads';
}
    
sub amplicon_fasta_file_for_contamination_screening {
    return $_[0]->contamination_dir.'/amplicon_reads.fasta';
}

sub create_contamination_dir {
    my $self = shift;

    return Genome::Utility::FileSystem->create_directory( $self->contamination_dir );
}

sub create_amplicon_fasta_files_for_contamination_screening {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    $self->create_contamination_dir
        or return;
    
    my $fasta_file = $self->amplicon_fasta_file_for_contamination_screening;
    unlink $fasta_file if -e $fasta_file;
    my $fasta_writer = Bio::SeqIO->new(
        '-file' => '>'.$fasta_file,
        '-fomat' => 'fasta',
    );
    for my $amplicon ( @$amplicons ) {
        for my $bioseq ( $amplicon->get_bioseq_for_raw_reads ) {
            $fasta_writer->write_seq($bioseq);
        }
    }

    return $fasta_file;
}

sub read_is_contaminated {
    my ($self, $read_name) = @_;

    # move reads for amplicon to contam dir
    die "not done\n";
    
    return 1;
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
