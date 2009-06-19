package Genome::Model::Build::AmpliconAssembly;

use strict;
use warnings;

use Genome;

require Genome::Model::Build::AmpliconAssembly::Amplicon;

class Genome::Model::Build::AmpliconAssembly {
    is => 'Genome::Model::Build',
};

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

#< DIRS >#
sub consed_directory {
    my $self = shift;

    unless ( $self->{_consed_directory} ) {
        $self->{_consed_directory} = Genome::Consed::Directory->create(directory => $self->data_directory);
    }

    return $self->{_consed_directory};
}

sub create_directory_structure {
    my $self = shift;

    $self->consed_directory->create_extended_directory_structure
        or return;

    return 1;
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

sub fasta_dir {
    return $_[0]->consed_directory->fasta_dir;
}

sub reports_dir {
    return $_[0]->data_directory.'/reports';
}

#< FASTA >#
my %_fasta_types_and_methods = (
    reads => 'get_bioseqs_for_raw_reads',
    processed => 'get_bioseqs_for_processed_reads',
    assembly => 'get_assembly_bioseq',
    oriented => 'get_oriented_bioseq',
);

sub amplicon_fasta_types {
    return keys %_fasta_types_and_methods;
}

sub amplicon_bioseq_method_for_type {
    return $_fasta_types_and_methods{$_[1]};
}

sub fasta_file_for_type {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.%s.fasta',
        $self->fasta_dir,
        $self->model->subject_name,
        $type,
    );
}

sub qual_file_for_type {
    return $_[0]->fasta_file_for_type($_[1]).'.qual';
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

#< AMPLICONS >#
sub amplicons {
    warn 'Method "amplicons" is deprecated.  Use get_amplicons or get_amplicons_and_reads\n';
    my $self = shift;

    my $method = sprintf('_determine_amplicons_in_chromat_dir_%s', $self->sequencing_center);
    my $amplicons = $self->$method;
    unless ( $amplicons and %$amplicons ) {
        $self->error_message(
            sprintf('No amplicons found in chromat_dir of model\'s (%s) build (<ID> %s)', $self->model->name, $self->id) 
        );
        return;
    }

    return $amplicons;
}

sub get_amplicons {
    my $self = shift;

    my $method = sprintf('_determine_amplicons_in_chromat_dir_%s', $self->model->sequencing_center);
    my $amplicons = $self->$method;
    unless ( $amplicons and %$amplicons ) {
        $self->error_message(
            sprintf('No amplicons found in chromat_dir of model\'s (%s) build (<ID> %s)', $self->model->name, $self->id) 
        );
        return;
    }

    my @amplicons;
    my $edit_dir = $self->edit_dir;
    for my $name ( keys %$amplicons ) {
        push @amplicons, Genome::Model::Build::AmpliconAssembly::Amplicon->new(
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

            return sprintf(">%s%s%s%s\n", $self->model->subject_name, @counters);
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

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
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

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
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

#<>#

1;

#$HeadURL$
#$Id$
